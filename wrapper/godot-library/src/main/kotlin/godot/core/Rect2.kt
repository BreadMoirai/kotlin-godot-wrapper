@file:Suppress("unused", "MemberVisibilityCanBePrivate")
package godot.core

import godot.gdnative.godot_rect2
import kotlinx.cinterop.*
import kotlin.math.max
import kotlin.math.min


class Rect2: CoreType {
    var pos = Vector2()
    var size = Vector2()


    constructor()

    constructor(x: Number, y: Number, width: Number, height: Number) {
        pos = Vector2(x, y)
        size = Vector2(width, height)
    }

    constructor(pos: Vector2, size: Vector2) {
        this.pos = pos
        this.size = size
    }


    internal constructor(native: CValue<godot_rect2>) {
        memScoped {
            this@Rect2.setRawMemory(native.ptr)
        }
    }
    internal constructor(mem: COpaquePointer) {
        this.setRawMemory(mem)
    }


    override fun getRawMemory(memScope: MemScope): COpaquePointer {
        return cValuesOf(pos[0].toFloat(), pos[1].toFloat(), size[0].toFloat(), size[1].toFloat()).getPointer(memScope)
    }
    override fun setRawMemory(mem: COpaquePointer) {
        val arr = mem.reinterpret<FloatVar>()
        pos[0] = arr[0].toDouble()
        pos[1] = arr[1].toDouble()
        size[0] = arr[2].toDouble()
        size[1] = arr[3].toDouble()
    }



    fun getArea(): Double = size.width * size.height

    fun intersects(rect: Rect2): Boolean =
            when {
                pos.x >= (rect.pos.x + rect.size.width) -> false
                (pos.x+size.width) <= rect.pos.x          -> false
                pos.y >= (rect.pos.y + rect.size.height)-> false
                (pos.y+size.height) <= rect.pos.y         -> false
                else                                        ->  true
            }

    fun encloses(rect: Rect2): Boolean =
            (rect.pos.x>=pos.x) && (rect.pos.y>=pos.y) &&
                    ((rect.pos.x+rect.size.x)<(pos.x+size.x)) &&
                    ((rect.pos.y+rect.size.y)<(pos.y+size.y))

    fun hasNoArea(): Boolean =
            size.x<=0 || size.y<=0

    fun hasPoint(point: Vector2): Boolean =
            when {
                point.x < pos.x           -> false
                point.y < pos.y           -> false
                point.x >= (pos.x+size.x) -> false
                point.y >= (pos.y+size.y) -> false
                else                        -> true
            }

    fun noArea(): Boolean =
            size.width<=0 || size.height<=0

    override fun equals(other: Any?): Boolean =
            when (other) {
                is Rect2 -> pos==other.pos && size==other.size
                else     -> false
            }

    fun grow(by: Double): Rect2 {
        val g = this
        g.pos.x -= by
        g.pos.y -= by
        g.size.width += by * 2
        g.size.height += by * 2
        return g
    }

    fun expand(vector: Vector2): Rect2 {
        val r = this
        r.expandTo(vector)
        return r
    }

    fun expandTo(vector: Vector2) {
        val begin = pos
        val end = pos + size

        if (vector.x < begin.x)
            begin.x = vector.x
        if (vector.y < begin.y)
            begin.y = vector.y

        if (vector.x > end.x)
            end.x = vector.x
        if (vector.y > end.y)
            end.y = vector.y

        pos = begin
        size = end-begin
    }


    fun distanceTo(point: Vector2): Double {
        var dist = 1e20
        if (point.x < pos.x) {
            dist = min(dist,pos.x-point.x)
        }
        if (point.y < pos.y) {
            dist = min(dist,pos.y-point.y)
        }
        if (point.x >= (pos.x+size.x) ) {
            dist= min(point.x-(pos.x+size.x),dist)
        }
        if (point.y >= (pos.y+size.y) ) {
            dist= min(point.y-(pos.y+size.y),dist)
        }
        return if (dist==1e20)
            0.0
        else
            dist
    }

    fun clip(rect: Rect2): Rect2 {
        if (!intersects(rect))
            return Rect2()

        rect.pos.x = max( rect.pos.x , pos.x )
        rect.pos.y = max( rect.pos.y , pos.y )

        val rectEnd = rect.pos+rect.size
        val end = pos+size

        rect.size.x = min(rectEnd.x,end.x) - rect.pos.x
        rect.size.y = min(rectEnd.y,end.y) - rect.pos.y

        return rect
    }

    fun merge(rect: Rect2): Rect2 {

        rect.pos.x= min( rect.pos.x , pos.x )
        rect.pos.y= min( rect.pos.y , pos.y )


        rect.size.x = max( rect.pos.x+rect.size.x , pos.x+size.x )
        rect.size.y = max( rect.pos.y+rect.size.y , pos.y+size.y )

        rect.size = rect.size - rect.pos //make relative again

        return rect
    }

    override fun toString(): String =
            pos.toString() + ", " + size.toString()

    fun intersectsSegment(from: Vector2, to: Vector2, boolPos: Boolean, boolNormal: Boolean): Triple<Boolean, Vector2?, Vector2?> {
        var min = 0.0
        var max = 1.0
        var axis = 0
        var sign = 0.0

        for (i in 0..1) {
            val segFrom = from[i]
            val segTo = to[i]
            val boxBegin = pos[i]
            val boxEnd = boxBegin + size[i]
            val cmin: Double
            val cmax: Double
            val csign: Double

            if (segFrom < segTo) {
                if (segFrom > boxEnd || segTo < boxBegin)
                    return Triple(false, null, null)
                val length=segTo-segFrom
                cmin = if (segFrom < boxBegin) ((boxBegin - segFrom)/length) else 0.0
                cmax = if (segTo > boxEnd) ((boxEnd - segFrom)/length) else 1.0
                csign = -1.0
            } else {
                if (segTo > boxEnd || segFrom < boxBegin)
                    return Triple(false, null, null)
                val length = segTo-segFrom
                cmin = if (segFrom > boxEnd) (boxEnd - segFrom)/length else 0.0
                cmax = if (segTo < boxBegin) (boxBegin - segFrom)/length else 1.0
                csign = 1.0
            }

            if (cmin > min) {
                min = cmin
                axis = i
                sign = csign
            }
            if (cmax < max)
                max = cmax
            if (max < min)
                return Triple(false, null, null)
        }

        val rel = to - from
        var normal: Vector2? = null
        var pos: Vector2? = null
        if (boolNormal) {
            normal = Vector2()
            normal[axis] = sign
        }

        if (boolPos)
            pos = from + rel * min

        return Triple(true, pos, normal)
    }

    fun intersectsTransformed(xform: Transform2D, rect: Rect2): Boolean {
        val xfPoints = arrayOf(xform.xform(rect.pos),
                xform.xform(Vector2(rect.pos.x+rect.size.x,rect.pos.y)),
                xform.xform(Vector2(rect.pos.x,rect.pos.y+rect.size.y)),
                xform.xform(Vector2(rect.pos.x+rect.size.x,rect.pos.y+rect.size.y)))

        var lowLimit = pos.y+size.y

        when {
            xfPoints[0].y > pos.y -> {}
            xfPoints[1].y > pos.y -> {}
            xfPoints[2].y > pos.y -> {}
            xfPoints[3].y > pos.y -> {}
            else -> return false
        }

        when {
            xfPoints[0].y < lowLimit -> {}
            xfPoints[1].y < lowLimit -> {}
            xfPoints[2].y < lowLimit -> {}
            xfPoints[3].y < lowLimit -> {}
            else -> return false
        }

        when {
            xfPoints[0].x > pos.x -> {}
            xfPoints[1].x > pos.x -> {}
            xfPoints[2].x > pos.x -> {}
            xfPoints[3].x > pos.x -> {}
            else -> return false
        }

        lowLimit = pos.x + size.x

        when {
            xfPoints[0].x < lowLimit -> {}
            xfPoints[1].x < lowLimit -> {}
            xfPoints[2].x < lowLimit -> {}
            xfPoints[3].x < lowLimit -> {}
            else -> return false
        }

        val xfPoints2 = arrayOf(pos,
                Vector2(pos.x+size.x,pos.y),
                Vector2(pos.x,pos.y+size.y),
                Vector2(pos.x+size.x,pos.y+size.y))

        var maxa = xform.elements[0].dot(xfPoints2[0])
        var mina = maxa

        var dp = xform.elements[0].dot(xfPoints2[1])
        maxa= max(dp,maxa)
        mina= min(dp,mina)

        dp = xform.elements[0].dot(xfPoints2[2])
        maxa= max(dp,maxa)
        mina= min(dp,mina)

        dp = xform.elements[0].dot(xfPoints2[3])
        maxa= max(dp,maxa)
        mina= min(dp,mina)

        var maxb=xform.elements[0].dot(xfPoints[0])
        var minb=maxb

        dp = xform.elements[0].dot(xfPoints[1])
        maxb= max(dp,maxb)
        minb= min(dp,minb)

        dp = xform.elements[0].dot(xfPoints[2])
        maxb= max(dp,maxb)
        minb= min(dp,minb)

        dp = xform.elements[0].dot(xfPoints[3])
        maxb= max(dp,maxb)
        minb= min(dp,minb)


        if ( mina > maxb || minb > maxa )
            return false

        maxa=xform.elements[1].dot(xfPoints2[0])
        mina=maxa

        dp = xform.elements[1].dot(xfPoints2[1])
        maxa= max(dp,maxa)
        mina= min(dp,mina)

        dp = xform.elements[1].dot(xfPoints2[2])
        maxa= max(dp,maxa)
        mina= min(dp,mina)

        dp = xform.elements[1].dot(xfPoints2[3])
        maxa= max(dp,maxa)
        mina= min(dp,mina)

        maxb=xform.elements[1].dot(xfPoints[0])
        minb=maxb

        dp = xform.elements[1].dot(xfPoints[1])
        maxb= max(dp,maxb)
        minb= min(dp,minb)

        dp = xform.elements[1].dot(xfPoints[2])
        maxb= max(dp,maxb)
        minb= min(dp,minb)

        dp = xform.elements[1].dot(xfPoints[3])
        maxb= max(dp,maxb)
        minb= min(dp,minb)

        if ( mina > maxb || minb > maxa )
            return false

        return true
    }

    override fun hashCode(): Int {
        var result = pos.hashCode()
        result = 31 * result + size.hashCode()
        return result
    }
}