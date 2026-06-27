#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_TARGET_ROBOT="robot_0"
readonly BAG_DIR="${HOME}/.ros/potbot_example/bags"
readonly NAVIGATION_LAUNCH="turtlebot3_navigation.launch"
readonly GAZEBO_WAIT_SEC=10
readonly NAVIGATION_WAIT_SEC=10
readonly ROSBAG_WAIT_SEC=2
readonly RESULT_WAIT_TIMEOUT_SEC=120

launch_file=""
count=""
target_robot="${DEFAULT_TARGET_ROBOT}"
goal_x=""
goal_y=""
goal_yaw=""
obstacle_specs=()

gazebo_pid=""
navigation_pid=""
rosbag_pid=""
obstacle_pids=()
active_obstacle_names=()

usage() {
  cat <<'USAGE'
Usage:
  run_sim_nav_record.sh --launch <launch file> --count <count> \
    --goal-x <x> --goal-y <y> --goal-yaw <yaw> \
    [--target-robot <namespace>] \
    [--obstacle <namespace>:<linear>:<angular>]...

Example:
  ./scripts/run_sim_nav_record.sh \
    --launch multi_robot_4.launch \
    --count 1 \
    --target-robot robot_0 \
    --goal-x 2.0 --goal-y -2.0 --goal-yaw 0.0 \
    --obstacle robot_1:0.2:0.5 \
    --obstacle robot_2:0.1:-0.3 \
    --obstacle robot_3:0.0:0.4

Arguments:
  --launch         Gazebo launch file name, such as multi_robot_1.launch.
  --count          Number of full simulation runs.
  --target-robot   Target robot namespace. Default: robot_0.
  --goal-x         Goal x position in the map frame.
  --goal-y         Goal y position in the map frame.
  --goal-yaw       Goal yaw in radians.
  --obstacle       Obstacle robot velocity as namespace:linear:angular.
                   This option can be specified multiple times.
  --help           Show this help.
USAGE
}

die() {
  echo "Error: $*" >&2
  exit 1
}

is_number() {
  [[ "$1" =~ ^[-+]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$ ]]
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --launch)
        (($# >= 2)) || die "--launch requires a value"
        launch_file="$2"
        shift 2
        ;;
      --count)
        (($# >= 2)) || die "--count requires a value"
        count="$2"
        shift 2
        ;;
      --target-robot)
        (($# >= 2)) || die "--target-robot requires a value"
        target_robot="$2"
        shift 2
        ;;
      --goal-x)
        (($# >= 2)) || die "--goal-x requires a value"
        goal_x="$2"
        shift 2
        ;;
      --goal-y)
        (($# >= 2)) || die "--goal-y requires a value"
        goal_y="$2"
        shift 2
        ;;
      --goal-yaw)
        (($# >= 2)) || die "--goal-yaw requires a value"
        goal_yaw="$2"
        shift 2
        ;;
      --obstacle)
        (($# >= 2)) || die "--obstacle requires a value"
        obstacle_specs+=("$2")
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

validate_args() {
  [[ -n "${launch_file}" ]] || die "--launch is required"
  [[ "${launch_file}" != */* ]] || die "--launch must be a file name, not a path"
  [[ "${launch_file}" == *.launch ]] || die "--launch must end with .launch"

  [[ -n "${count}" ]] || die "--count is required"
  is_positive_integer "${count}" || die "--count must be a positive integer"

  [[ -n "${target_robot}" ]] || die "--target-robot must not be empty"
  [[ "${target_robot}" =~ ^[A-Za-z0-9_]+$ ]] || die "--target-robot must contain only letters, numbers, and underscores"

  [[ -n "${goal_x}" ]] || die "--goal-x is required"
  [[ -n "${goal_y}" ]] || die "--goal-y is required"
  [[ -n "${goal_yaw}" ]] || die "--goal-yaw is required"
  is_number "${goal_x}" || die "--goal-x must be a number"
  is_number "${goal_y}" || die "--goal-y must be a number"
  is_number "${goal_yaw}" || die "--goal-yaw must be a number"

  for spec in "${obstacle_specs[@]}"; do
    IFS=":" read -r namespace linear angular extra <<<"${spec}"
    [[ -z "${extra:-}" ]] || die "--obstacle must be namespace:linear:angular: ${spec}"
    [[ -n "${namespace}" && -n "${linear}" && -n "${angular}" ]] || die "--obstacle must be namespace:linear:angular: ${spec}"
    [[ "${namespace}" =~ ^[A-Za-z0-9_]+$ ]] || die "obstacle namespace must contain only letters, numbers, and underscores: ${namespace}"
    is_number "${linear}" || die "obstacle linear velocity must be a number: ${spec}"
    is_number "${angular}" || die "obstacle angular velocity must be a number: ${spec}"
  done
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

package_path() {
  rospack find potbot_example
}

validate_environment() {
  require_command roslaunch
  require_command rostopic
  require_command rosbag
  require_command rospack
  require_command awk
  require_command timeout

  local pkg_path
  pkg_path="$(package_path)" || die "potbot_example package was not found by rospack"
  if [[ ! -f "${pkg_path}/launch/${launch_file}" && ! -f "${pkg_path}/launch/gazebo/${launch_file}" ]]; then
    die "launch file was not found in potbot_example/launch or potbot_example/launch/gazebo: ${launch_file}"
  fi
}

unique_topics() {
  awk '!seen[$0]++'
}

build_rosbag_topics() {
  {
    printf '/clock\n'
    printf '/tf\n'
    printf '/tf_static\n'
    printf '/%s/odom\n' "${target_robot}"
    printf '/%s/scan\n' "${target_robot}"
    printf '/%s/cmd_vel\n' "${target_robot}"
    printf '/%s/goal\n' "${target_robot}"
    printf '/%s/map\n' "${target_robot}"
    printf '/%s/move_base/GlobalPlanner/plan\n' "${target_robot}"
    printf '/%s/move_base/local_costmap/costmap\n' "${target_robot}"
    printf '/%s/camera/depth/points/obstacles\n' "${target_robot}"

    for spec in "${obstacle_specs[@]}"; do
      IFS=":" read -r namespace _linear _angular <<<"${spec}"
      printf '/%s/odom\n' "${namespace}"
      printf '/%s/scan\n' "${namespace}"
      printf '/%s/cmd_vel\n' "${namespace}"
      printf '/%s/camera/depth/points/obstacles\n' "${namespace}"
    done
  } | unique_topics
}

twist_message() {
  local linear="$1"
  local angular="$2"
  cat <<TWIST
linear:
  x: ${linear}
  y: 0.0
  z: 0.0
angular:
  x: 0.0
  y: 0.0
  z: ${angular}
TWIST
}

pose_message() {
  local x="$1"
  local y="$2"
  local yaw="$3"
  local qz
  local qw
  qz="$(awk -v yaw="${yaw}" 'BEGIN { printf "%.12g", sin(yaw / 2.0) }')"
  qw="$(awk -v yaw="${yaw}" 'BEGIN { printf "%.12g", cos(yaw / 2.0) }')"

  cat <<POSE
header:
  frame_id: "map"
pose:
  position:
    x: ${x}
    y: ${y}
    z: 0.0
  orientation:
    x: 0.0
    y: 0.0
    z: ${qz}
    w: ${qw}
POSE
}

stop_pid() {
  local pid="$1"
  [[ -n "${pid}" ]] || return 0
  kill -0 "${pid}" >/dev/null 2>&1 || return 0
  kill -INT "${pid}" >/dev/null 2>&1 || true
  wait "${pid}" >/dev/null 2>&1 || true
}

publish_zero_obstacles() {
  for namespace in "${active_obstacle_names[@]}"; do
    rostopic pub --once "/${namespace}/cmd_vel" geometry_msgs/Twist "$(twist_message 0.0 0.0)" >/dev/null 2>&1 || true
  done
}

cleanup_run() {
  for pid in "${obstacle_pids[@]}"; do
    stop_pid "${pid}"
  done
  obstacle_pids=()

  publish_zero_obstacles
  active_obstacle_names=()

  stop_pid "${rosbag_pid}"
  stop_pid "${navigation_pid}"
  stop_pid "${gazebo_pid}"

  rosbag_pid=""
  navigation_pid=""
  gazebo_pid=""
}

handle_interrupt() {
  echo
  echo "Interrupted. Stopping running processes..."
  cleanup_run
  exit 130
}

start_obstacles() {
  local spec
  for spec in "${obstacle_specs[@]}"; do
    local namespace
    local linear
    local angular
    IFS=":" read -r namespace linear angular <<<"${spec}"
    active_obstacle_names+=("${namespace}")
    rostopic pub -r 10 "/${namespace}/cmd_vel" geometry_msgs/Twist "$(twist_message "${linear}" "${angular}")" &
    obstacle_pids+=("$!")
  done
}

publish_goal() {
  rostopic pub --once "/${target_robot}/goal" geometry_msgs/PoseStamped "$(pose_message "${goal_x}" "${goal_y}" "${goal_yaw}")"
}

wait_for_goal_result() {
  echo "Waiting up to ${RESULT_WAIT_TIMEOUT_SEC}s for /${target_robot}/move_base/result. Press Ctrl-C to stop."
  if timeout "${RESULT_WAIT_TIMEOUT_SEC}s" rostopic echo -n 1 "/${target_robot}/move_base/result" >/dev/null; then
    return 0
  fi

  local status="$?"
  if [[ "${status}" -eq 124 ]]; then
    echo "Timed out waiting for /${target_robot}/move_base/result."
    return 0
  fi

  return "${status}"
}

run_once() {
  local run_index="$1"
  local run_suffix
  local bag_path
  local -a topics

  run_suffix="$(printf 'run%02d' "${run_index}")"
  bag_path="${BAG_DIR}/${launch_file%.launch}_$(date +%Y%m%d_%H%M%S)_${run_suffix}.bag"
  mapfile -t topics < <(build_rosbag_topics)

  echo "[$run_suffix] Starting Gazebo: ${launch_file}"
  roslaunch potbot_example "${launch_file}" &
  gazebo_pid="$!"
  sleep "${GAZEBO_WAIT_SEC}"

  echo "[$run_suffix] Starting navigation: ${NAVIGATION_LAUNCH} multi_robot:=${target_robot}"
  roslaunch potbot_example "${NAVIGATION_LAUNCH}" "multi_robot:=${target_robot}" &
  navigation_pid="$!"
  sleep "${NAVIGATION_WAIT_SEC}"

  mkdir -p "${BAG_DIR}"
  echo "[$run_suffix] Recording bag: ${bag_path}"
  rosbag record -O "${bag_path}" "${topics[@]}" &
  rosbag_pid="$!"
  sleep "${ROSBAG_WAIT_SEC}"

  echo "[$run_suffix] Publishing obstacle velocities"
  start_obstacles

  echo "[$run_suffix] Publishing goal to /${target_robot}/goal"
  publish_goal

  wait_for_goal_result
  echo "[$run_suffix] Goal result received. Stopping run."
  cleanup_run
}

main() {
  parse_args "$@"
  validate_args
  validate_environment
  trap handle_interrupt INT TERM
  trap cleanup_run EXIT

  local i
  for ((i = 1; i <= count; i++)); do
    run_once "${i}"
  done

  trap - EXIT
  cleanup_run
  echo "All runs completed."
}

main "$@"
