#!/usr/bin/env python
# -*- coding: utf-8 -*-

import rospy
import rosparam
from std_srvs.srv import Empty

def call_service(service_name):
    rospy.wait_for_service(service_name)
    try:
        srv = rospy.ServiceProxy(service_name, Empty)
        srv()  
        rospy.loginfo("Successfully called "+service_name)
    except rospy.ServiceException as e:
        rospy.logerr("Service call failed: %s" % e)

if __name__ == "__main__":
    rospy.init_node('simulation_node')
    rate = rospy.Rate(1)  
    while not rospy.is_shutdown():
        # rosparam.set_param('/robot_1/follow_marker/publish_command', "false")
        call_service('/gazebo/reset_world')
        call_service('/robot_0/move_base/clear_costmaps')
        # rate.sleep()
        break
