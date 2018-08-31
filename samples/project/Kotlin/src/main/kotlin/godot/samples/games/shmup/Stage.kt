package godot.samples.games.shmup

import godot.*
import godot.core.NodePath

class Stage: Node() {

    lateinit var Enemy: PackedScene
    lateinit var EnemyPath: PackedScene
    lateinit var Player: PackedScene
    lateinit var player: Area2D
    var respawnTime = 0

    override fun _ready() {
        Enemy = PackedScene from ResourceLoader.load("res://Games/Shmup/Scenes/Enemy.tscn")
        EnemyPath = PackedScene from ResourceLoader.load("res://Games/Shmup/Scenes/EnemyPath.tscn")
        Player = PackedScene from ResourceLoader.load("res://Games/Shmup/Scenes/Player.tscn")
        player = Area2D from Player.instance()
        addChild(player)
    }

    override fun _process(delta: Double) {
        respawnTime++
        val count = getTree().getNodesInGroup("enemies").size()
        if(respawnTime > 30 && count < 4) {
            loadEnemy()
            respawnTime = 0
        }
    }

    fun loadEnemy() {
        val newEnemy = Enemy.instance()
        val newPath = EnemyPath.instance().apply {
            getNode(NodePath("PathFollow2D")).addChild(newEnemy)
        }
        addChild(newPath)
    }

}