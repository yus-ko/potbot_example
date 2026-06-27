# 前提条件
- ros melodicがインストール済み
- potbot_exampleとその依存パッケージがインストールおよびビルド済み
- 基本的なrosコマンド(rostopic, roslaunch, etc.)を使用可能

# シミュレーション再現手順

## gazeboの起動
以下のコマンドで、提出論文の各図に対応するTurtleBot3のGazeboシミュレーションを起動できます。

| 対応図 | 実行コマンド |
| --- | --- |
| Fig. 9 | `roslaunch potbot_example multi_robot_1.launch` |
| Fig. 10 | `roslaunch potbot_example multi_robot_2.launch` |
| Fig. 11 | `roslaunch potbot_example multi_robot_3.launch` |
| Fig. 12 | `roslaunch potbot_example multi_robot_4.launch` |

障害物やロボットの配置を変更する場合は、対応するlaunchファイルまたはworldファイルを編集します。ここでは`multi_robot_1.launch`を例に説明します。対象箇所は`potbot_example/launch/gazebo/multi_robot_1.launch:8-16`（制御対象ロボット`robot_0`）と`potbot_example/launch/gazebo/multi_robot_1.launch:19-26`（移動障害物ロボット`robot_1`）です。

```xml
<include file="$(find potbot_example)/launch/gazebo/spawn_model/spawn_turtlebot3.launch">
    <arg name="tf_prefix"       value="robot_0"/>
    <arg name="x_pos"           value="2.0"/>
    <arg name="y_pos"           value="6.0"/>
    <arg name="z_pos"           value="0.01"/>
    <arg name="yaw"             value="-1.57"/>
```

例えば、`<arg name="x_pos" value="2.0"/>`を`<arg name="x_pos" value="3.0"/>`に変更すると、制御対象ロボット`robot_0`の初期位置のx座標が3になります。同様に、`y_pos`でy座標、`yaw`で姿勢を変更できます。移動障害物ロボットの位置を変更する場合は、`robot_1`の`x_pos`、`y_pos`、`yaw`の値を変更してください。

静止障害物（上記環境では円柱のオブジェクト）の配置を変更する場合は、`potbot_example/worlds/willowgarage_1.world:170-172`の以下の値を編集します。

```xml
    <model name='unit_cylinder'>
      <pose frame=''>2.01742 -2.60774 0.5 0 -0 0</pose>
```

`pose`の値は、左からx[m]、y[m]、z[m]、roll[rad]、pitch[rad]、yaw[rad]です。

円柱のサイズを変更する場合は、`potbot_example/worlds/willowgarage_1.world:185-189`（`collision`）と`potbot_example/worlds/willowgarage_1.world:206-210`（`visual`）にある、以下の`radius`と`length`を編集します。

```xml
        <collision name='collision'>
          <geometry>
            <cylinder>
              <radius>0.5</radius>
              <length>1</length>
            </cylinder>
```

```xml
        <collision name='visual'>
          <geometry>
            <cylinder>
              <radius>0.5</radius>
              <length>1</length>
            </cylinder>
```

サイズは`collision`と`visual`の2箇所で設定されています。`collision`のみを変更した場合、Gazebo GUI上の表示サイズは変更されないため注意してください。

## 障害物ロボットの動かし方
[gazebo](#gazeboの起動)では複数台のturtlebot3を起動できます。それぞれのturtlebot3にはネームスペースが設定されており、制御対象のロボットには`robot_0`、移動障害物ロボットには`robot_1`以降の番号を割り当てています。例えば、`multi_robot_1.launch`において`robot_1`付のcmd_velトピックをパブリッシュすることで障害物ロボットを動かすことができます。  
並進速度0.2[m/s]、回転速度0.5[m/s]で動かすコマンド例；
```bash
rostopic pub --once /robot_1/cmd_vel geometry_msgs/Twist "linear:
  x: 0.2
  y: 0.0
  z: 0.0
angular:
  x: 0.0
  y: 0.0
  z: 0.5"
```
停止させる：
```bash
rostopic pub --once /robot_1/cmd_vel geometry_msgs/Twist "linear:
  x: 0.0
  y: 0.0
  z: 0.0
angular:
  x: 0.0
  y: 0.0
  z: 0.0"
```

## ナビゲーションの起動
[gazebo](#gazeboの起動)を行った後、以下のコマンドでturtlebot3のナビゲーションプログラムを実行できます。
