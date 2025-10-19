# ros2-tb3
Docker and Dev Container build for ROS2 Humble Hawksbill with TurtleBot3 components.
The image contains the following additional software:

* [MoveIt2 and tutorials](https://moveit.picknik.ai/main/index.html)
* [rtabmap](https://github.com/introlab/rtabmap)
* [ARGoS3 multi robot simulator](https://www.argos-sim.info/index.php)

It also contains a more [recent version](https://launchpad.net/~kisak/+archive/ubuntu/turtle/) of 
[Mesa](https://mesa3d.org/), with better support for OpenGL on D3D12, suitable for using this image on WSL2.