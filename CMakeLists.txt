cmake_minimum_required(VERSION 3.0.2)
project(potbot_example)

find_package(catkin REQUIRED COMPONENTS
  pcl_ros
  potbot_lib
  potbot_msgs
)

catkin_package(
#   INCLUDE_DIRS include
  LIBRARIES ${PROJECT_NAME} potbot_lib
)

include_directories(
  include
  ${catkin_INCLUDE_DIRS}
)

add_executable(twist_to_odometry src/twist_to_odometry.cpp)
target_link_libraries(twist_to_odometry ${catkin_LIBRARIES})

add_definitions(-std=c++14)