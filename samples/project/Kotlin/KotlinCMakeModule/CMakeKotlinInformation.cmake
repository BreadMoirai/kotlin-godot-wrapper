if (CMAKE_USER_MAKE_RULES_OVERRIDE)
    # Save the full path of the file so try_compile can use it.
    include(${CMAKE_USER_MAKE_RULES_OVERRIDE} RESULT_VARIABLE _override)
    set(CMAKE_USER_MAKE_RULES_OVERRIDE "${_override}")
endif ()

if (CMAKE_USER_MAKE_RULES_OVERRIDE_Kotlin)
    # Save the full path of the file so try_compile can use it.
    include(${CMAKE_USER_MAKE_RULES_OVERRIDE_Kotlin} RESULT_VARIABLE _override)
    set(CMAKE_USER_MAKE_RULES_OVERRIDE_Kotlin "${_override}")
endif ()

if (NOT CMAKE_Kotlin_COMPILE_OBJECT)
    set(CMAKE_Kotlin_COMPILE_OBJECT "")
    # more native CMake without cinterop would be:
    # set(CMAKE_Kotlin_COMPILE_OBJECT "$(CMAKE_COMMAND) -E copy <SOURCE> <OBJECT>")
endif ()

if (NOT CMAKE_Kotlin_LINK_EXECUTABLE)
    set(CMAKE_Kotlin_LINK_EXECUTABLE "")
    # more native CMake without cinterop would be:
    # set(CMAKE_Kotlin_LINK_EXECUTABLE "${CMAKE_Kotlin_COMPILER} <OBJECTS> -o <TARGET>")
endif ()

set(CMAKE_Kotlin_FLAGS "" CACHE STRING
        "Flags used by the compiler during all build types.")
set(CMAKE_Kotlin_FLAGS_DEBUG "-g" CACHE STRING
        "Flags used by the compiler during debug builds.")
set(CMAKE_Kotlin_FLAGS_MINSIZEREL "-opt" CACHE STRING
        "Flags used by the compiler during release builds for minimum size.")
set(CMAKE_Kotlin_FLAGS_RELEASE "-opt" CACHE STRING
        "Flags used by the compiler during release builds.")
set(CMAKE_Kotlin_FLAGS_RELWITHDEBINFO "-opt -g" CACHE STRING
        "Flags used by the compiler during release builds with debug info.")

set(CMAKE_Kotlin_LIBRARY_DIR ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/libs/)

mark_as_advanced(
        CMAKE_Kotlin_FLAGS
        CMAKE_Kotlin_FLAGS_DEBUG
        CMAKE_Kotlin_FLAGS_RELEASE
)

FILE(WRITE "${CMAKE_CURRENT_BINARY_DIR}/kotlin_native_model.json" "// Kotlin/Native Model. Generated by CMake, do not edit.\n")

function(add_model_record CMAKE_TARGET_NAME TYPE KONANC_TARGET SOURCES LIBRARIES OUTPUT)
    FILE(APPEND "${CMAKE_CURRENT_BINARY_DIR}/kotlin_native_model.json" "\
{\
\"cMakeTargetName\": \"${CMAKE_TARGET_NAME}\", \
\"type\": \"${TYPE}\", \
\"targetPlatform\": \"${KONANC_TARGET}\", \
\"sources\": \"${SOURCES}\", \
\"libraries\": \"${LIBRARIES}\", \
\"output\": \"${OUTPUT}\"\
}\n")

endfunction()

function(cinterop)
    cmake_parse_arguments(
            CINTEROP
            ""
            "NAME;DEF_FILE;TARGET"
            "LIBRARIES;COMPILER_OPTS"
            ${ARGN}
    )
    if (NOT CINTEROP_NAME)
        message(FATAL_ERROR "You must provide a name")
    endif ()

    if (NOT CINTEROP_DEF_FILE)
        message(FATAL_ERROR "You must provide def file location")
    endif ()

    if (NOT CINTEROP_TARGET)
        if (APPLE)
            set(CINTEROP_TARGET macbook)
        elseif (UNIX)
            set(CINTEROP_TARGET linux)
        elseif (WIN32)
            set(CINTEROP_TARGET mingw_x64)
        else ()
            message(FATAL_ERROR "Unsupported host target")
        endif ()
    endif ()

    set(TARGET_FLAG -target ${CINTEROP_TARGET})
    set(LIBRARY_${CINTEROP_NAME}_TARGET ${CINTEROP_TARGET} CACHE STRING "Library ${CINTEROP_NAME} target" FORCE)

    set(COMPILER_OPTS_FLAG)
    foreach (COMPILER_OPT ${CINTEROP_COMPILER_OPTS})
        set(COMPILER_OPTS_FLAG ${COMPILER_OPTS_FLAG} -compilerOpts ${COMPILER_OPT})
    endforeach ()

    set(LIBRARY_FLAG)
    foreach (LIBRARY ${CINTEROP_LIBRARIES})
        set(LIBRARY_FLAG ${LIBRARY_FLAG} -library ${LIBRARY})
    endforeach ()

    set(LIBRARY_OUTPUT ${CMAKE_Kotlin_LIBRARY_DIR}/${CINTEROP_NAME}.klib)
    set(LIBRARY_${CINTEROP_NAME}_OUTPUT ${LIBRARY_OUTPUT} CACHE PATH "Library ${CINTEROP_NAME}" FORCE)

    add_model_record("${CINTEROP_NAME}" CINTEROP "${CINTEROP_TARGET}" "${CINTEROP_DEF_FILE}" "${CINTEROP_LIBRARIES}" "${LIBRARY_OUTPUT}")
    add_custom_command(
            OUTPUT ${LIBRARY_OUTPUT}
            DEPENDS ${CINTEROP_DEF_FILE} ${CINTEROP_LIBRARIES}
            COMMAND ${CMAKE_Kotlin_CINTEROP} ${COMPILER_OPTS_FLAG} ${LIBRARY_FLAG}
            -def ${CMAKE_CURRENT_SOURCE_DIR}/${CINTEROP_DEF_FILE} ${TARGET_FLAG}
            -r ${CMAKE_Kotlin_LIBRARY_DIR} -o ${LIBRARY_OUTPUT}
    )
    add_custom_target(${CINTEROP_NAME}
            DEPENDS ${LIBRARY_OUTPUT}
            SOURCES ${CINTEROP_DEF_FILE})

    foreach (LIBRARY ${CINTEROP_LIBRARIES})
        add_dependencies(${CINTEROP_NAME} ${LIBRARY})
    endforeach ()

endfunction()

include(CMakeParseArguments)

macro(prepare_konanc_args)
    cmake_parse_arguments(
            KONANC
            ""
            "NAME;TARGET"
            "SOURCES;TEST_SOURCES;LIBRARIES;LINKER_OPTS"
            ${ARGN}
    )

    if (NOT KONANC_NAME)
        message(FATAL_ERROR "You must provide a name")
    endif ()

    if (NOT KONANC_SOURCES)
        message(FATAL_ERROR "You must provide list of sources")
    endif ()

    if (NOT KONANC_TARGET)
        if (APPLE)
            set(KONANC_TARGET macbook)
        elseif (UNIX)
            set(KONANC_TARGET linux)
        elseif (WIN32)
            set(KONANC_TARGET mingw_x64)
        else ()
            message(FATAL_ERROR "Unsupported host target")
        endif ()
    endif ()

    set(TARGET_FLAG -target ${KONANC_TARGET})
    set(LIBRARY_${KONANC_NAME}_TARGET ${KONANC_TARGET} CACHE STRING "Konanc ${KONANC_NAME} target" FORCE)

    set(LINKER_OPTS_FLAG)
    if (KONANC_LINKER_OPTS)
        foreach (LINKER_OPT ${KONANC_LINKER_OPTS})
            set(LINKER_OPTS_FLAG ${LINKER_OPTS_FLAG} -linkerOpts ${LINKER_OPT})
        endforeach ()
    endif ()

    set(LIBRARY_PATH)
    foreach (KONANC_LIBRARY ${KONANC_LIBRARIES})
        set(LIBRARY_PATH ${LIBRARY_PATH} -library ${KONANC_LIBRARY})
    endforeach ()

    set(ADDITIONAL_KONANC_FLAGS ${CMAKE_Kotlin_FLAGS})
    if (CMAKE_BUILD_TYPE STREQUAL "Debug")
        string(APPEND ADDITIONAL_KONANC_FLAGS " ${CMAKE_Kotlin_FLAGS_DEBUG}")
    elseif (CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
        string(APPEND ADDITIONAL_KONANC_FLAGS " ${CMAKE_Kotlin_FLAGS_MINSIZEREL}")
    elseif (CMAKE_BUILD_TYPE STREQUAL "Release")
        string(APPEND ADDITIONAL_KONANC_FLAGS " ${CMAKE_Kotlin_FLAGS_RELEASE}")
    elseif (CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
        string(APPEND ADDITIONAL_KONANC_FLAGS " ${CMAKE_Kotlin_FLAGS_RELWITHDEBINFO}")
    endif ()
    separate_arguments(ADDITIONAL_KONANC_FLAGS)

    set(KOTLINC_EXPANDED_SOURCES "")
    foreach (folder ${KONANC_SOURCES})
        list(APPEND KOTLINC_EXPANDED_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/${folder})
        file(GLOB_RECURSE KT_FILES ${CMAKE_CURRENT_SOURCE_DIR}/${folder}/*.kt)
        foreach (file ${KT_FILES})
            list(APPEND KOTLINC_EXPANDED_SOURCES ${file})
        endforeach (file ${KT_FILES})
    endforeach (folder ${KONANC_SOURCES})
endmacro()

macro(prepare_klib_args)
    cmake_parse_arguments(
            KLIB
            ""
            "NAME;TARGET"
            "PATH;LIBRARIES"
            ${ARGN}
    )

    if (NOT KLIB_NAME)
        message(FATAL_ERROR "You must provide a name")
    endif ()

    if (NOT KLIB_PATH)
        message(FATAL_ERROR "You must provide path to library file")
    endif ()

    if (NOT KLIB_TARGET)
        if (APPLE)
            set(KLIB_TARGET macbook)
        elseif (UNIX)
            set(KLIB_TARGET linux)
        elseif (WIN32)
            set(KLIB_TARGET mingw_x64)
        else ()
            message(FATAL_ERROR "Unsupported host target")
        endif ()
    endif ()

endmacro()

function(konanc_executable)
    prepare_konanc_args(${ARGV})

    set(KONANC_${KONANC_NAME}_EXECUTABLE_PATH ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${KONANC_NAME})

    if(${KONANC_TARGET} STREQUAL "wasm32")
        set(EXECUTABLE_EXTENSION "wasm")
    elseif (${KONANC_TARGET} STREQUAL "android_arm32")
        set(EXECUTABLE_EXTENSION "so")
    elseif (${KONANC_TARGET} STREQUAL "android_arm64")
        set(EXECUTABLE_EXTENSION "so")
    else()
        set(EXECUTABLE_EXTENSION "exe")
    endif()
    set(OUTPUT_EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/${KONANC_NAME}.${EXECUTABLE_EXTENSION})

    add_model_record("${KONANC_NAME}.${EXECUTABLE_EXTENSION}" EXECUTABLE "${KONANC_TARGET}" "${KONANC_SOURCES}" "${KONANC_LIBRARIES}" "${OUTPUT_EXECUTABLE}")
    add_custom_command(
            OUTPUT ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP.${EXECUTABLE_EXTENSION}
            DEPENDS ${KOTLINC_EXPANDED_SOURCES}
            COMMAND ${CMAKE_Kotlin_COMPILER} ${ADDITIONAL_KONANC_FLAGS} ${KONANC_SOURCES}
            ${LIBRARY_PATH} ${TARGET_FLAG} ${LINKER_OPTS_FLAG} -r ${CMAKE_Kotlin_LIBRARY_DIR}
            -o ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP
            COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_BINARY_DIR}/${KONANC_NAME}.${EXECUTABLE_EXTENSION}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_target(${KONANC_NAME}.compile
            DEPENDS ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP.${EXECUTABLE_EXTENSION}
            SOURCES ${KONANC_SOURCES})

    foreach (KONANC_LIBRARY ${KONANC_LIBRARIES})
        add_dependencies(${KONANC_NAME}.compile ${KONANC_LIBRARY})
    endforeach ()

    add_executable(${KONANC_NAME}.${EXECUTABLE_EXTENSION} ${KONANC_SOURCES})
    add_dependencies(${KONANC_NAME}.${EXECUTABLE_EXTENSION} ${KONANC_NAME}.compile)
    set_target_properties(${KONANC_NAME}.${EXECUTABLE_EXTENSION} PROPERTIES LINKER_LANGUAGE Kotlin)
    add_custom_command(TARGET ${KONANC_NAME}.${EXECUTABLE_EXTENSION}
            PRE_LINK
            COMMAND ${CMAKE_COMMAND} -E copy ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP.${EXECUTABLE_EXTENSION} ${OUTPUT_EXECUTABLE})

    if(${KONANC_TARGET} STREQUAL "wasm32")
        add_custom_command(TARGET ${KONANC_NAME}.${EXECUTABLE_EXTENSION}
                PRE_LINK
                COMMAND ${CMAKE_COMMAND} -E copy ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP.${EXECUTABLE_EXTENSION}.js ${OUTPUT_EXECUTABLE}.js)
    endif()

    if (KONANC_TEST_SOURCES)
        konanc_test(
                NAME ${KONANC_NAME}_test
                TARGET ${KONANC_TARGET}
                SOURCES ${KONANC_SOURCES} ${KONANC_TEST_SOURCES}
                LIBRARIES ${KONANC_LIBRARIES}
                LINKER_OPTS ${KONANC_LINKER_OPTS}
        )
    endif ()

endfunction()

function(konanc_library)
    prepare_konanc_args(${ARGV})

    set(LIBRARY_OUTPUT ${CMAKE_Kotlin_LIBRARY_DIR}/${KONANC_NAME}.klib)
    set(LIBRARY_${KONANC_NAME}_OUTPUT ${LIBRARY_OUTPUT} CACHE PATH "Library ${KONANC_NAME}" FORCE)

    add_model_record("${KONANC_NAME}" LIBRARY "${KONANC_TARGET}" "${KONANC_SOURCES}" "${KONANC_LIBRARIES}" "${LIBRARY_OUTPUT}")
    add_custom_command(
            OUTPUT ${LIBRARY_OUTPUT}
            DEPENDS ${KOTLINC_EXPANDED_SOURCES}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_Kotlin_LIBRARY_DIR}
            COMMAND ${CMAKE_Kotlin_COMPILER} -produce library ${ADDITIONAL_KONANC_FLAGS}
            ${KONANC_SOURCES} ${LIBRARY_PATH} ${TARGET_FLAG} ${LINKER_OPTS_FLAG}
            -r ${CMAKE_Kotlin_LIBRARY_DIR} -o ${LIBRARY_OUTPUT} --disable devirtualization
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_target(${KONANC_NAME}
            DEPENDS ${LIBRARY_OUTPUT}
            SOURCES ${KONANC_SOURCES})

    foreach (KONANC_LIBRARY ${KONANC_LIBRARIES})
        add_dependencies(${KONANC_NAME} ${KONANC_LIBRARY})
    endforeach ()

    set_target_properties(${KONANC_NAME} PROPERTIES LINKER_LANGUAGE Kotlin)

    if (KONANC_TEST_SOURCES)
        konanc_test(
                NAME ${KONANC_NAME}_test
                TARGET ${KONANC_TARGET}
                SOURCES ${KONANC_SOURCES} ${KONANC_TEST_SOURCES}
                LIBRARIES ${KONANC_LIBRARIES}
                LINKER_OPTS ${KONANC_LINKER_OPTS}
        )
    endif ()

endfunction()

function(konanc_dynamic)
    prepare_konanc_args(${ARGV})

    set(LIBRARY_OUTPUT ${CMAKE_Kotlin_LIBRARY_DIR}/${KONANC_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX})
    set(LIBRARY_${KONANC_NAME}_OUTPUT ${LIBRARY_OUTPUT} CACHE PATH "Dynamic library ${KONANC_NAME}" FORCE)

    add_model_record("${KONANC_NAME}" LIBRARY "${KONANC_TARGET}" "${KONANC_SOURCES}" "${KONANC_LIBRARIES}" "${LIBRARY_OUTPUT}")
    add_custom_command(
            OUTPUT ${LIBRARY_OUTPUT}
            DEPENDS ${KOTLINC_EXPANDED_SOURCES}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_Kotlin_LIBRARY_DIR}
            COMMAND ${CMAKE_Kotlin_COMPILER} -produce dynamic ${ADDITIONAL_KONANC_FLAGS}
            ${KONANC_SOURCES} ${LIBRARY_PATH} ${TARGET_FLAG} ${LINKER_OPTS_FLAG}
            -r ${CMAKE_Kotlin_LIBRARY_DIR} -o ${LIBRARY_OUTPUT} --disable devirtualization
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_target(${KONANC_NAME}
            DEPENDS ${LIBRARY_OUTPUT}
            SOURCES ${KONANC_SOURCES})

    foreach (KONANC_LIBRARY ${KONANC_LIBRARIES})
        add_dependencies(${KONANC_NAME} ${KONANC_LIBRARY})
    endforeach ()

    set_target_properties(${KONANC_NAME} PROPERTIES LINKER_LANGUAGE Kotlin)

    if (KONANC_TEST_SOURCES)
        konanc_test(
                NAME ${KONANC_NAME}_test
                TARGET ${KONANC_TARGET}
                SOURCES ${KONANC_SOURCES} ${KONANC_TEST_SOURCES}
                LIBRARIES ${KONANC_LIBRARIES}
                LINKER_OPTS ${KONANC_LINKER_OPTS}
        )
    endif ()

endfunction()

function(konanc_test)
    prepare_konanc_args(${ARGV})

    set(KONANC_${KONANC_NAME}_EXECUTABLE_PATH ${CMAKE_CURRENT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/${KONANC_NAME})
    set(EXECUTABLE_OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${KONANC_NAME}.exe)

    add_model_record("${KONANC_NAME}.exe" TEST_EXECUTABLE "${KONANC_TARGET}" "${KONANC_SOURCES}" "${KONANC_LIBRARIES}" "${EXECUTABLE_OUTPUT}")
    add_custom_command(
            OUTPUT ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP.exe
            DEPENDS ${KOTLINC_EXPANDED_SOURCES}
            COMMAND ${CMAKE_Kotlin_COMPILER} -tr ${ADDITIONAL_KONANC_FLAGS} ${KONANC_SOURCES}
            ${LIBRARY_PATH} ${TARGET_FLAG} ${LINKER_OPTS_FLAG} -r ${CMAKE_Kotlin_LIBRARY_DIR}
            -o ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP
            COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_BINARY_DIR}/${KONANC_NAME}.exe
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_target(${KONANC_NAME}.compile
            DEPENDS ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP.exe
            SOURCES ${KONANC_SOURCES})

    foreach (KONANC_LIBRARY ${KONANC_LIBRARIES})
        add_dependencies(${KONANC_NAME}.compile ${KONANC_LIBRARY})
    endforeach ()

    add_executable(${KONANC_NAME}.exe ${KONANC_SOURCES})
    add_dependencies(${KONANC_NAME}.exe ${KONANC_NAME}.compile)
    set_target_properties(${KONANC_NAME}.exe PROPERTIES LINKER_LANGUAGE Kotlin)
    add_custom_command(TARGET ${KONANC_NAME}.exe
            PRE_LINK
            COMMAND ${CMAKE_COMMAND} -E copy ${KONANC_${KONANC_NAME}_EXECUTABLE_PATH}_TEMP.exe ${EXECUTABLE_OUTPUT})

endfunction()

function(konanc_library_search LIB_NAME INCLUDE_FILE)
    #TODO REMOVE ME(!)
    if (UNIX AND NOT APPLE)
        enable_language(C)
    endif()
    string(TOUPPER ${LIB_NAME} UPPER_LIB_NAME)

    find_library(${UPPER_LIB_NAME}_LIBRARY ${LIB_NAME})
    if (NOT ${UPPER_LIB_NAME}_LIBRARY)
        message(WARNING "Library ${LIB_NAME} not found")
    endif()

    find_file(${UPPER_LIB_NAME}_INCLUDE_FILE ${INCLUDE_FILE})
    get_filename_component(${UPPER_LIB_NAME}_INCLUDE_DIR ${${UPPER_LIB_NAME}_INCLUDE_FILE} DIRECTORY)

    get_filename_component(${UPPER_LIB_NAME}_LIBRARY_DIR ${${UPPER_LIB_NAME}_LIBRARY} DIRECTORY)
    set(${UPPER_LIB_NAME}_LIBRARY_DIR ${${UPPER_LIB_NAME}_LIBRARY_DIR} PARENT_SCOPE)
    set(${UPPER_LIB_NAME}_LIBRARY ${${UPPER_LIB_NAME}_LIBRARY} PARENT_SCOPE)
    set(${UPPER_LIB_NAME}_INCLUDE_DIR ${${UPPER_LIB_NAME}_INCLUDE_DIR} PARENT_SCOPE)
endfunction()

function(klib)
    prepare_klib_args(${ARGV})

    set(LIBRARY_OUTPUT ${CMAKE_Kotlin_LIBRARY_DIR}/${KLIB_NAME}.klib)
    set(LIBRARY_${KLIB_NAME}_OUTPUT ${LIBRARY_OUTPUT} CACHE PATH "Library ${KLIB_NAME}" FORCE)

    add_model_record("${KLIB_NAME}" LIBRARY "${KLIB_TARGET}" "${KLIB_PATH}" "${KLIB_LIBRARIES}" "${LIBRARY_OUTPUT}")
    add_custom_target(${KLIB_NAME}
            DEPENDS ${KLIB_PATH})
    add_custom_command(TARGET ${KLIB_NAME}
            PRE_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy ${KLIB_PATH} ${LIBRARY_OUTPUT})

    foreach (KLIB_LIBRARY ${KLIB_LIBRARIES})
        add_dependencies(${KLIB_NAME} ${KLIB_LIBRARY})
    endforeach ()

    set_target_properties(${KONANC_NAME} PROPERTIES LINKER_LANGUAGE Kotlin)
endfunction()