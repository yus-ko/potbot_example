# 前提条件
- ros melodicがインストール済み
- potbot_exampleとその依存パッケージがインストールおよびビルド済み
- 基本的なrosコマンド(rostopic, roslaunch, etc.)を使用可能

# シミュレーション再現手順

この手順は、`potbot_example`リポジトリのコミット[5c26482](https://github.com/yus-ko/potbot_example/tree/5c264822179a903ae0dd307a7c32393a2774ceee)時点の構成に基づいて説明しています。

## gazeboの起動
以下のコマンドで、提出論文の各図に対応するturtlebot3のgazeboシミュレーションを起動できます。

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
[gazeboの起動](#gazeboの起動)では複数台のturtlebot3を起動できます。それぞれのturtlebot3にはネームスペースが設定されており、制御対象のロボットには`robot_0`、移動障害物ロボットには`robot_1`以降の番号を割り当てています。例えば、`multi_robot_1.launch`において`robot_1`付のcmd_velトピックをパブリッシュすることで障害物ロボットを動かすことができます。  
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
[gazeboの起動](#gazeboの起動)を行った後、以下のコマンドでturtlebot3のナビゲーションプログラムを実行できます。

```bash
roslaunch potbot_example turtlebot3_navigation.launch
```

制御対象ロボットは、`potbot_example/launch/turtlebot3_navigation.launch:14`の`multi_robot`で指定します。デフォルト値は`robot_0`です。`multi_robot`の値は、フレームID、センサートピック、速度指令トピック、ゴールトピックに反映されます（`potbot_example/launch/turtlebot3_navigation.launch:20-27`）。また、ナビゲーション関連ノードは`potbot_example/launch/turtlebot3_navigation.launch:43`で`multi_robot`のネームスペース内に起動されます。

例えば、制御対象を`robot_1`に変更する場合は、起動時に以下のように指定します。

```bash
roslaunch potbot_example turtlebot3_navigation.launch multi_robot:=robot_1
```

`PotbotLocalPlanner`のパラメーターは、`potbot_example/launch/turtlebot3_navigation.launch:90`で指定している`potbot_example/config/navigation/optimal_path_follower.yaml`を編集して変更します。このYAMLは`potbot_example/launch/navigation/move_base.launch:36`で読み込まれます。

```yaml
base_local_planner: potbot_nav/PotbotLocalPlanner

PotbotLocalPlanner:
  controller_name: potbot_nav/OPF
  recover_distance: 0.01
```

速度や停止距離などの制御パラメーターは、`potbot_example/config/navigation/optimal_path_follower.yaml:7-13`の`controller`、および`potbot_example/config/navigation/optimal_path_follower.yaml:15-20`の`recover`で変更できます。`move_base`側では、`potbot_example/launch/navigation/move_base.launch:37-38`で`PotbotLocalPlanner/controller/frame_id_global`と`PotbotLocalPlanner/path_planner_name`も設定しています。

## シミュレーション・ナビゲーション・rosbag recordの一括実行

`scripts/run_sim_nav_record.sh`を使用すると、gazebo、ナビゲーション、主要トピックのrosbag record、ゴールポーズのパブリッシュ、移動障害物ロボットへの速度指令をまとめて実行できます。

このスクリプトは、ros melodicと`potbot_example`が使用可能な環境で実行します。
`potbot_example/`ディレクトリ内で以下を実行して使用方法を確認できます。
```bash
./scripts/run_sim_nav_record.sh --help
```

基本的な実行例は以下の通りです。

```bash
./scripts/run_sim_nav_record.sh \
  --launch multi_robot_4.launch \
  --count 1 \
  --target-robot robot_0 \
  --timeout 300 \
  --goal-x 2.0 \
  --goal-y -2.0 \
  --goal-yaw 0.0 \
  --obstacle robot_1:0.2:0.5 \
  --obstacle robot_2:0.1:-0.3 \
  --obstacle robot_3:0.0:0.4
```

引数は以下の通りです。

| 引数 | 説明 |
| --- | --- |
| `--launch` | gazeboで起動するlaunchファイル名を指定します。例: `multi_robot_1.launch` |
| `--count` | シミュレーション全体の実行回数を指定します。各回でgazebo、ナビゲーション、rosbag recordを起動し直します。 |
| `--target-robot` | 制御対象ロボットのネームスペースを指定します。省略時は`robot_0`です。 |
| `--timeout` | ゴールパブリッシュ後に`/<target-robot>/move_base/result`を待つ最大秒数を指定します。省略時は300秒です。 |
| `--goal-x` | mapフレーム上のゴール位置x座標を指定します。 |
| `--goal-y` | mapフレーム上のゴール位置y座標を指定します。 |
| `--goal-yaw` | mapフレーム上のゴール姿勢yaw角[rad]を指定します。 |
| `--obstacle` | 移動障害物ロボットの速度を`ネームスペース:並進速度:回転速度`形式で指定します。複数回指定できます。 |
| `--help` | 使用方法を表示します。 |

`--target-robot`で指定したロボットに対して、`turtlebot3_navigation.launch multi_robot:=<ネームスペース>`が起動されます。また、ゴールポーズは`/<ネームスペース>/goal`へ`geometry_msgs/PoseStamped`としてパブリッシュされます。

`--obstacle`は移動障害物ロボットごとに個別の速度を指定できます。例えば、`robot_1`を前進しながら左回転、`robot_2`を低速で右回転させる場合は以下のように指定します。

```bash
--obstacle robot_1:0.2:0.5 --obstacle robot_2:0.1:-0.3
```

rosbagファイルは`~/.ros/potbot_example/bags/`に保存されます。ファイル名は`<launchファイル名>_<日時>_runNN.bag`です。記録対象には`/clock`、`/tf`、`/tf_static`、制御対象ロボットの`odom`、`scan`、`cmd_vel`、`goal`、`map`、move_base関連トピック、各障害物ロボットの`odom`、`scan`、`cmd_vel`、深度点群トピックが含まれます。

各回は`/<target-robot>/move_base/result`を受信すると終了し、次の回へ進みます。resultを受信できない場合は、ゴールパブリッシュ後`--timeout`で指定した秒数が経過するとその回を終了します。途中で停止する場合は`Ctrl-C`を押してください。停止時は、指定した各障害物ロボットへゼロ速度を送信してから、rosbag record、ナビゲーション、gazeboを終了します。
