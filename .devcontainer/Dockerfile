FROM osrf/ros:humble-desktop-full

# Add ubuntu user with same UID and GID as your host system, if it doesn't already exist
# Since Ubuntu 24.04, a non-root user is created by default with the name vscode and UID=1000
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN if ! id -u $USER_UID >/dev/null 2>&1; then \
        groupadd --gid $USER_GID $USERNAME && \
        useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME; \
    fi
# Add sudo support for the non-root user
RUN apt-get update && \
    apt-get install -y sudo && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Install alsa-utils so we can setup null plugin
RUN apt install -y alsa-utils
RUN echo 'pcm.!default { type null }' >> /etc/asound.conf

# Update all packages
RUN apt update && apt upgrade -y

# Install Git and other utilities
RUN apt install -y git psmisc wget acl software-properties-common

# Install Gazebo
RUN apt install -y gazebo

# Install Turtlebot
RUN apt update && apt install -y ros-humble-dynamixel-sdk ros-humble-turtlebot3-msgs ros-humble-turtlebot3 ros-humble-turtlebot3-gazebo ros-humble-turtlebot3-navigation2 ros-humble-turtlebot3-simulations ros-humble-turtlebot3-teleop

# Install rtabmap-ros
RUN apt update && apt install -y ros-humble-rtabmap-ros

# Install movit2
RUN apt update && apt install -y ros-humble-moveit ros-humble-moveit-resources-panda-moveit-config

# Install extra Gazebo plugins
RUN apt update && apt install -y ros-humble-gazebo-ros2-control

# Install RMW CycloneDDS
# RUN apt install -y ros-humble-rmw-cyclonedds-cpp

# Install useful Python3 packages
RUN apt install -y python3-pip python3-rosdep python3-argcomplete python3-transforms3d

# Install mesa utils
RUN apt update && apt install -y mesa-utils

# Update mesa drivers to latest version
RUN add-apt-repository ppa:kisak/turtle && \
    apt update && \
    apt upgrade -y 

# Switch from root to user
USER $USERNAME

# Fix fluxbox environment
RUN mkdir -p /home/$USERNAME/.fluxbox/styles
COPY fluxbox/init /home/$USERNAME/.fluxbox/init
COPY fluxbox/menu /home/$USERNAME/.fluxbox/menu
COPY fluxbox/qnx-photon-mod /home/$USERNAME/.fluxbox/styles/qnx-photon-mod

# Add user to video group to allow access to webcam
RUN sudo usermod --append --groups video $USERNAME

# Rosdep update
RUN rosdep update

# Ignore warning for colcon builds
RUN echo 'export PYTHONWARNINGS=ignore:::setuptools.command.install,ignore:::setuptools.command.easy_install,ignore:::pkg_resources' >> ~/.bashrc

# Disable Gazebo classic EOL notices
RUN echo 'export GAZEBO_SUPPRESS_EOL_WARNING=1' >> ~/.bashrc

# Disable Gazebo logging by default
RUN echo 'export GAZEBO_LOG_ENABLE=0' >> ~/.bashrc

# Colcon_cd
RUN echo "source /usr/share/colcon_cd/function/colcon_cd.sh" >> ~/.bashrc
RUN echo "export _colcon_cd_root=/opt/ros/humble/" >> ~/.bashrc

# Colcon auto-complete
RUN echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash" >> ~/.bashrc

# Set default RMW implementation
# RUN echo 'export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp' >> ~/.bashrc

# Set default turtlebot3 model
RUN echo 'export TURTLEBOT3_MODEL=waffle_pi' >> ~/.bashrc

# Gazebo configuration
RUN echo 'source /usr/share/gazebo/setup.sh' >> ~/.bashrc

# Source the ROS setup file
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc

# Install useful Python3 packages from pip as user
RUN pip install gdown pydantic angles transitions python-statemachine

# Update PATH
RUN echo "export PATH=\$PATH:/home/ubuntu/.local/bin" >> ~/.bashrc

# Setup movit2_tutorials
SHELL ["/bin/bash", "-c"]
# RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
#     mkdir -p /home/$USERNAME/ws_moveit/src && \
#     cd /home/$USERNAME/ws_moveit/src && \
#     git clone -b ${ROS_DISTRO} https://github.com/moveit/moveit_task_constructor.git && \
#     git clone -b ${ROS_DISTRO} https://github.com/moveit/moveit2_tutorials && \
#     cd ../ && \
#     rosdep install -r --from-paths . --ignore-src --rosdistro ${ROS_DISTRO} -y && \
#     colcon build && \
#     rm -rf build/ log/ src/ && \
#     echo "source /home/${USERNAME}/ws_moveit/install/setup.bash" >> ~/.bashrc

# Install moveit2 from source, including tutorials
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    mkdir -p /home/${USERNAME}/ws_moveit/src && \
    cd /home/${USERNAME}/ws_moveit/src && \
    colcon --log-base /dev/null mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon --log-base /dev/null mixin update default && \
    git clone -b main https://github.com/moveit/moveit2_tutorials && \
    vcs import --recursive < moveit2_tutorials/moveit2_tutorials.repos && \
    sudo apt remove ros-$ROS_DISTRO-moveit* -y && \
    sudo apt update && rosdep install -r --from-paths . --ignore-src --rosdistro $ROS_DISTRO -y && \
    cd /home/${USERNAME}/ws_moveit/ && \
    colcon build --mixin release && \
    rm -rf build/ log/ src/ && \
    echo "source /home/${USERNAME}/ws_moveit/install/setup.bash" >> ~/.bashrc

# Install ARGoS3 simulator
RUN /home/${USERNAME}/.local/bin/gdown --fuzzy https://drive.google.com/file/d/1gnWfCqNmbCQbxNDenp5-ek7P5bvTNgyD/view?usp=share_link -O /home/${USERNAME}/argos3_simulator-3.0.0-x86_64-beta59.deb && \
    sudo apt update && sudo apt install /home/${USERNAME}/argos3_simulator-3.0.0-x86_64-beta59.deb && \
    rm /home/${USERNAME}/argos3_simulator-3.0.0-x86_64-beta59.deb

# Install ARGoS3 examples and build them
RUN git clone https://github.com/ilpincy/argos3-examples.git /home/${USERNAME}/argos3-examples && \
    mkdir -p /home/${USERNAME}/argos3-examples/build && \
    cd /home/${USERNAME}/argos3-examples/build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make

# Set ARGoS3 alias to use llvmpipe if running in a container without GPU support or WSL2
RUN echo '\
argos3() {\n\
  if [ "\$GALLIUM_DRIVER" = "d3d12" ]; then\n\
    GALLIUM_DRIVER=llvmpipe command argos3 "\$@"\n\
  else\n\
    command argos3 "\$@"\n\
  fi\n\
}' >> ~/.bashrc