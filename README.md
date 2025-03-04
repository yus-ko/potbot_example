# potbot_example

<!-- テスト環境
| ROS |
--
| Melodic |
| Kinetic | -->

# Installation

はじめに https://github.com/yus-ko/potbot_core をビルドしてください

次に以下のコマンドで必要なパッケージをインストールしてください

```bash
sudo apt install ros-$ROS_DISTRO-gmapping ros-$ROS_DISTRO-map-server ros-$ROS_DISTRO-robot-localization ros-$ROS_DISTRO-rtabmap-ros ros-$ROS_DISTRO-imu-tools -y
sudo apt install ros-$ROS_DISTRO-gazebo-ros ros-$ROS_DISTRO-gazebo-ros-control ros-$ROS_DISTRO-ros-control ros-$ROS_DISTRO-ros-controllers ros-$ROS_DISTRO-turtlebot3 -y
mkdir -p ~/.gazebo/models && cd ~/.gazebo/models
git clone https://github.com/osrf/gazebo_models
mv ~/.gazebo/models/gazebo_models/* ~/.gazebo/models/ && sudo rm -r ~/.gazebo/models/gazebo_models/
```

<!-- git clone https://github.com/ROBOTIS-GIT/turtlebot3_msgs -b $ROS_DISTRO-devel
git clone https://github.com/ROBOTIS-GIT/turtlebot3 -b $ROS_DISTRO-devel -->
```bash
cd ~/catkin_ws/src
git clone https://github.com/vstoneofficial/megarover_samples
git clone https://github.com/vstoneofficial/vs_rover_options_description
git clone https://github.com/vstoneofficial/megarover_description
git clone https://github.com/yus-ko/multiple_robots_slam
```
```bash
cd ~/catkin_ws
catkin build megarover_samples vs_rover_options_description megarover_description multi_turtlebot_gazebo
```

```bash
cd ~/catkin_ws/src
git clone https://github.com/yus-ko/potbot_example
```
```bash
cd ~/catkin_ws
catkin build potbot_example
```

# 起動方法

gazeboが実行されます
```bash
roslaunch potbot_example turtlebot3_with_garage.launch
```

rvizを使用するナビゲーションプログラムが実行されます
```bash  
roslaunch potbot_example turtlebot3_navigation.launch
```