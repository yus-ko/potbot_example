cmake_minimum_required(VERSION 3.5)
project(potbot_example)

find_package(ament_cmake REQUIRED)

install(DIRECTORY
  launch
  maps
  params
  rviz
  worlds
  DESTINATION share/${PROJECT_NAME}
)

if(BUILD_TESTING)
  find_package(ament_cmake_pytest REQUIRED)

  ament_add_pytest_test(test_navigation_e2e
    test/test_navigation_e2e.py
    TIMEOUT 180
  )
endif()

ament_package()