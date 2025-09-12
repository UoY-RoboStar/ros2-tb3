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
RUN apt update && sudo apt upgrade -y

# Install Git
RUN apt install -y git

# Install Gazebo
RUN apt install -y gazebo

# Install Turtlebot
RUN apt install -y ros-humble-dynamixel-sdk ros-humble-turtlebot3-msgs ros-humble-turtlebot3 ros-humble-turtlebot3-gazebo

# Install RMW CycloneDDS
RUN apt install -y ros-humble-rmw-cyclonedds-cpp

# Switch from root to user
USER $USERNAME

# Fix fluxbox environment
COPY fluxbox/init /home/$USERNAME/.fluxbox/init
COPY fluxbox/menu /home/$USERNAME/.fluxbox/menu
COPY fluxbox/qnx-photon-mod /home/$USERNAME/.fluxbox/qnx-photon-mod

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
RUN echo 'export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp' >> ~/.bashrc

# Set default turtlebot3 model
RUN echo 'export TURTLEBOT3_MODEL=waffle_pi' >> ~/.bashrc

# Gazebo configuration
RUN echo 'source /usr/share/gazebo/setup.sh' >> ~/.bashrc

# Source the ROS setup file
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc

################################
## ADD ANY CUSTOM SETUP BELOW ##
################################
