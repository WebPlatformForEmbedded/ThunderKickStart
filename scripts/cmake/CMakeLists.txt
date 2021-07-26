# This will extract stuff from cmake
cmake_minimum_required(VERSION 3.0)
project(cmakechecker)

configure_file( "${CMAKE_CURRENT_LIST_DIR}/cmake-environment.in"
                "${CMAKE_BINARY_DIR}/cmake-environment"
                @ONLY)

install(FILES "dummy"
        DESTINATION "dummy"
        OPTIONAL)
