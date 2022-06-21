# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html

# Sets the minimum version of CMake required to build the native library.

cmake_minimum_required(VERSION 3.10.2)

# Declares and names the project.

project("composer")
#导入头文件
include_directories(./invs)
include_directories(./include)
#set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -L[${CMAKE_SOURCE_DIR}/jniLibs/armeabi-v7a]")

# Creates and names a library, sets it as either STATIC
# or SHARED, and provides the relative paths to its source code.
# You can define multiple libraries, and CMake builds them for you.
# Gradle automatically packages shared libraries with your APK.
#添加链接库
add_library(avdevice-57
        # Sets the library as a shared library.
        SHARED
        # Provides a relative path to your source file(s).
        IMPORTED  )
set_target_properties( avdevice-57
        PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/jniLibs/${CMAKE_ANDROID_ARCH_ABI}/libavdevice-57.so )

add_library(avformat-57
        SHARED
        IMPORTED  )
set_target_properties( avformat-57
        PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/jniLibs/armeabi-v7a/libavformat-57.so )

add_library(avcodec-57
        SHARED
        IMPORTED  )
set_target_properties(avcodec-57
        PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/jniLibs/armeabi-v7a/libavcodec-57.so )

add_library( avfilter-6
        SHARED
        IMPORTED  )
set_target_properties( avfilter-6
        PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/jniLibs/armeabi-v7a/libavfilter-6.so )

add_library( avutil-55
        SHARED
        IMPORTED  )
set_target_properties( avutil-55
        PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/jniLibs/armeabi-v7a/libavutil-55.so )

add_library( swresample-2
        SHARED
        IMPORTED  )
set_target_properties( swresample-2
        PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/jniLibs/armeabi-v7a/libswresample-2.so )

add_library( swscale-4
        SHARED
        IMPORTED  )
set_target_properties( swscale-4
        PROPERTIES IMPORTED_LOCATION
        ${CMAKE_SOURCE_DIR}/jniLibs/armeabi-v7a/libswscale-4.so )

add_library( # Sets the name of the library.
        composer

        # Sets the library as a shared library.
        SHARED

        # Provides a relative path to your source file(s).
        native-lib.cpp
        AVpacket_queue.cpp
        Utils.cpp
)

# Searches for a specified prebuilt library and stores the path as a
# variable. Because CMake includes system libraries in the search path by
# default, you only need to specify the name of the public NDK library
# you want to add. CMake verifies that the library exists before
# completing its build.

find_library( # Sets the name of the path variable.
        log-lib

        # Specifies the name of the NDK library that
        # you want CMake to locate.
        log)

#find_library(avdevice-57 avdevice-57 PATHS ./jniLibs/armeabi-v7a/ NO_CMAKE_FIND_ROOT_PATH)
#find_library(avcodec-57 avcodec-57 PATHS ./jniLibs/armeabi-v7a/ NO_CMAKE_FIND_ROOT_PATH)

target_link_libraries(composer

        avdevice-57
        avformat-57
        avcodec-57
        avfilter-6
        avutil-55
        swresample-2
        swscale-4

        -landroid
        # Links the target library to the log library
        # included in the NDK.
        ${log-lib})

