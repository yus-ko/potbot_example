cmake_minimum_required(VERSION 3.5)
project(potbot_example)

find_package(ament_cmake REQUIRED)

install(DIRECTORY
  launch params rviz worlds
  DESTINATION share/${PROJECT_NAME}
)

ament_package()