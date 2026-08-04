# syntax=docker/dockerfile:1.10.0

# osrf/ros:humble-desktop-full is amd64-only, so we build on the multi-arch
# ros:humble-ros-base image (amd64 + arm64) and apt-install desktop-full ourselves.
FROM ros:humble-ros-base

# Populated automatically by buildx (e.g. "amd64", "arm64")
ARG TARGETARCH

# ROS's setup.bash uses bash-only syntax, so it can't be sourced under the default
# /bin/sh (dash); switch the build shell to bash for the rest of the Dockerfile.
SHELL ["/bin/bash", "-c"]

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
RUN apt install -y git psmisc wget acl software-properties-common lxterminal

# Install the ROS desktop packages (rviz2, demos, perception, ...) that used to
# come from the osrf/ros:humble-desktop-full base image. We deliberately install
# ros-humble-desktop + ros-humble-perception rather than ros-humble-desktop-full:
# the "-full" metapackage also pulls in ros-humble-simulation (the Ignition/ros_gz
# stack), which this project doesn't use (Gazebo classic is installed separately
# below) and which currently has a broken arm64 dependency chain in the ROS apt
# repo (libignition-gazebo6 requires libignition-sensors6 >= 6.8.1, but only
# 6.8.0 is installable for arm64 at the time of writing).
RUN apt update && apt install -y ros-humble-desktop ros-humble-perception

# Install Gazebo from Pedro Ribeiro's PPA (https://launchpad.net/~pfribeiro/+archive/ubuntu/ppa).
# Ubuntu jammy does not ship a "gazebo"/"libgazebo-dev" binary for arm64, so the stock
# archive can't be used on that architecture; the PPA publishes both amd64 and arm64 builds.
RUN add-apt-repository -y ppa:pfribeiro/ppa && \
    apt install -y gazebo libgazebo-dev

# Install Turtlebot3
RUN apt update && apt install -y ros-humble-dynamixel-sdk ros-humble-turtlebot3-msgs ros-humble-turtlebot3 ros-humble-turtlebot3-navigation2 ros-humble-turtlebot3-teleop

# Build the Gazebo/Turtlebot3 simulation integration from source. ros-humble-turtlebot3-gazebo,
# ros-humble-turtlebot3-simulations and ros-humble-gazebo-ros2-control are only published as
# amd64 binaries by the ROS build farm, so to keep the same codebase on every architecture
# these are always compiled from source rather than installed from apt on amd64 only, following
# https://docs.robotis.com/docs/systems/turtlebot3/simulation/gazebo_simulation
RUN mkdir -p /opt/turtlebot3_gazebo_ws/src && \
    cd /opt/turtlebot3_gazebo_ws/src && \
    git clone -b ros2 https://github.com/ros-simulation/gazebo_ros_pkgs.git && \
    git clone -b humble https://github.com/ros-simulation/gazebo_ros2_control.git && \
    git clone -b humble https://github.com/ROBOTIS-GIT/turtlebot3_simulations.git && \
    cd /opt/turtlebot3_gazebo_ws && \
    source /opt/ros/${ROS_DISTRO}/setup.bash && \
    rosdep update && \
    rosdep install --from-paths src --ignore-src -r -y && \
    colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release && \
    rm -rf src build log && \
    echo "source /opt/turtlebot3_gazebo_ws/install/setup.bash" >> /etc/bash.bashrc

# Install rtabmap-ros
RUN apt update && apt install -y ros-humble-rtabmap-ros

# Install movit2
RUN apt update && apt install -y ros-humble-moveit ros-humble-moveit-resources-panda-moveit-config

# Install RMW CycloneDDS
# RUN apt install -y ros-humble-rmw-cyclonedds-cpp

# Install useful Python3 packages
RUN apt install -y python3-pip python3-rosdep python3-argcomplete python3-transforms3d

# Install mesa utils
RUN apt update && apt install -y mesa-utils

# Install OpenCL for Intel (amd64 only; intel-opencl-icd isn't published for arm64)
RUN apt update && apt install -y clinfo && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        apt install -y intel-opencl-icd; \
    fi

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

# Install moveit2 from source, including tutorials.
# ros2_kortex/ros2_robotiq_gripper/serial are only pulled in by moveit2_tutorials.repos
# as a temporary source stand-in "until rolling binaries are available" (per its own
# comments) for an unrelated Kinova-arm demo; nothing else in the tutorials depends on
# them. kortex_api (part of ros2_kortex) vendors a prebuilt SDK that is hard-coded to
# reject any architecture other than x86_64, so these are removed rather than built.
# The moveit binary packages are removed *twice*: once before rosdep so its resolution
# isn't confused by them, and again right after rosdep (before colcon build). This is
# needed because rosdep install --ignore-src still resolves the unrelated binary
# package ros-$ROS_DISTRO-kinova-gen3-7dof-robotiq-2f-85-moveit-config (a rosdep key
# from the same Kinova demo, but not part of the ros2_kortex/ros2_robotiq_gripper
# source repos removed above), and apt pulls the entire moveit binary stack back in as
# its dependencies. Left in place, those binary headers (e.g. moveit_setup_framework's
# templates.hpp) shadow the freshly-built source headers and cause a spurious
# "'variables' was not declared" compile error in moveit_setup_app_plugins - regardless
# of which moveit2 commit is checked out, so pinning moveit2 to a fixed SHA does not
# help; the second apt remove is the actual fix.
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    mkdir -p /home/${USERNAME}/ws_moveit/src && \
    cd /home/${USERNAME}/ws_moveit/src && \
    colcon --log-base /dev/null mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon --log-base /dev/null mixin update default && \
    git clone -b main https://github.com/moveit/moveit2_tutorials && \
    vcs import --recursive < moveit2_tutorials/moveit2_tutorials.repos && \
    rm -rf ros2_kortex ros2_robotiq_gripper serial && \
    sudo apt remove ros-$ROS_DISTRO-moveit* -y && \
    sudo apt update && rosdep install -r --from-paths . --ignore-src --rosdistro $ROS_DISTRO -y && \
    sudo apt remove ros-$ROS_DISTRO-moveit* -y && \
    cd /home/${USERNAME}/ws_moveit/ && \
    colcon build --mixin release && \
    rm -rf build/ log/ src/ && \
    echo "source /home/${USERNAME}/ws_moveit/install/setup.bash" >> ~/.bashrc

# Install ARGoS3 simulator (amd64 only: the prebuilt .deb below is x86_64-only and there is
# no arm64 build available yet, so the ARGoS3 tooling is skipped entirely on arm64)
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        /home/${USERNAME}/.local/bin/gdown --fuzzy https://drive.google.com/file/d/1gnWfCqNmbCQbxNDenp5-ek7P5bvTNgyD/view?usp=share_link -O /home/${USERNAME}/argos3_simulator-3.0.0-x86_64-beta59.deb && \
        sudo apt update && sudo apt install -y /home/${USERNAME}/argos3_simulator-3.0.0-x86_64-beta59.deb && \
        rm /home/${USERNAME}/argos3_simulator-3.0.0-x86_64-beta59.deb; \
    fi

# Install ARGoS3 examples and build them (amd64 only, see above)
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        git clone https://github.com/ilpincy/argos3-examples.git /home/${USERNAME}/argos3-examples && \
        mkdir -p /home/${USERNAME}/argos3-examples/build && \
        cd /home/${USERNAME}/argos3-examples/build && \
        cmake -DCMAKE_BUILD_TYPE=Release .. && \
        make; \
    fi

# Install GSL libraries
RUN sudo apt update && sudo apt install -y libgsl27 libgsl-dev

# Install ARGos3 ROS2 bridge (amd64 only, depends on ARGoS3 above)
RUN --mount=type=secret,id=GIT_AUTH_TOKEN,env=GIT_AUTH_TOKEN if [ "$TARGETARCH" = "amd64" ]; then \
        export OpenGL_GL_PREFERENCE=GLVND && \
        mkdir -p /home/${USERNAME}/bridge_ws/src && \
        git clone https://${GIT_AUTH_TOKEN}@github.com/UoY-RoboStar/argos3-ros2-bridge.git /home/${USERNAME}/bridge_ws/src/argos3-ros2-bridge && \
        cd /home/${USERNAME}/bridge_ws && \
        source /opt/ros/${ROS_DISTRO}/setup.bash && \
        colcon build --packages-select argos3_ros2_bridge && \
        colcon build --packages-select argos3_ros2_bridge --cmake-args -DFIRST_TIME=Off && \
        echo "export ARGOS_PLUGIN_PATH=/home/${USERNAME}/argos3-examples:/home/${USERNAME}/bridge_ws/install/argos3_ros2_bridge/lib:\$ARGOS_PLUGIN_PATH" >> ~/.bashrc && \
        echo "export LD_LIBRARY_PATH=\$ARGOS_PLUGIN_PATH:\$LD_LIBRARY_PATH" >> ~/.bashrc && \
        echo "source /home/${USERNAME}/bridge_ws/install/local_setup.bash" >> ~/.bashrc; \
    fi

# Set ARGoS3 alias to use llvmpipe if running in a container without GPU support or WSL2
RUN cat <<'EOF' >> ~/.bashrc
argos3() {
  if [ "$GALLIUM_DRIVER" = "d3d12" ]; then
    GALLIUM_DRIVER=llvmpipe command argos3 "$@"
  else
    command argos3 "$@"
  fi
}
EOF

ARG USERNAME=ubuntu
USER $USERNAME

# Install pangolin dependencies and other required packages
RUN sudo apt update && sudo apt install -y libglew-dev ffmpeg unzip

# Pangolin
RUN cd /home/${USERNAME}/ && \
    git clone https://github.com/stevenlovegrove/Pangolin.git && \
    cd Pangolin && \  
    git checkout ad8b5f83 && \ 
    sed -i -e "193,198d" ./src/utils/file_utils.cpp && \ 
    mkdir -p build && \
    cd build && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_PANGOLIN_DEPTHSENSE=OFF \
    -DBUILD_PANGOLIN_FFMPEG=OFF \
    -DBUILD_PANGOLIN_LIBDC1394=OFF \
    -DBUILD_PANGOLIN_LIBJPEG=OFF \
    -DBUILD_PANGOLIN_LIBOPENEXR=OFF \
    -DBUILD_PANGOLIN_LIBPNG=OFF \
    -DBUILD_PANGOLIN_LIBREALSENSE=OFF \
    -DBUILD_PANGOLIN_LIBREALSENSE2=OFF \
    -DBUILD_PANGOLIN_LIBTIFF=OFF \
    -DBUILD_PANGOLIN_LIBUVC=OFF \
    -DBUILD_PANGOLIN_LZ4=OFF \
    -DBUILD_PANGOLIN_OPENNI=OFF \
    -DBUILD_PANGOLIN_OPENNI2=OFF \
    -DBUILD_PANGOLIN_PLEORA=OFF \
    -DBUILD_PANGOLIN_PYTHON=OFF \
    -DBUILD_PANGOLIN_TELICAM=OFF \
    -DBUILD_PANGOLIN_TOON=OFF \
    -DBUILD_PANGOLIN_UVC_MEDIAFOUNDATION=OFF \
    -DBUILD_PANGOLIN_V4L=OFF \
    -DBUILD_PANGOLIN_VIDEO=OFF \
    -DBUILD_PANGOLIN_ZSTD=OFF \
    -DBUILD_PYPANGOLIN_MODULE=OFF \
    .. && \
    make -j$(($(nproc) / 2)) && \
    sudo make install && \
    cd / && rm -rf Pangolin

# Iridescence
RUN sudo apt update && sudo apt install -y libglm-dev libglfw3-dev libpng-dev libjpeg-dev libeigen3-dev libboost-filesystem-dev libboost-program-options-dev && \
    cd /home/${USERNAME}/ && \
    git clone https://github.com/koide3/iridescence.git && \
    cd iridescence && \
    git checkout 085322e0c949f75b67d24d361784e85ad7f197ab && \
    git submodule update --init --recursive && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo .. && \
    make -j"$(($(nproc)/2))" && \
    sudo make install && \
    rm -rf /home/${USERNAME}/iridescence

# Stella VSLAM
SHELL ["/bin/bash", "-c"]
RUN mkdir -p /home/${USERNAME}/lib && \
    cd /home/${USERNAME}/lib && \
    git clone --recursive --depth 1 https://github.com/stella-cv/stella_vslam.git && \
    rosdep install -y -i --from-paths ~/lib && \
    cd /home/${USERNAME}/lib/stella_vslam && \
    mkdir -p /home/${USERNAME}/lib/stella_vslam/build && \
    cd /home/${USERNAME}/lib/stella_vslam/build && \
    source /opt/ros/${ROS_DISTRO}/setup.bash && \
    cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo .. && \
    make -j"$(($(nproc)/2))" && \
    sudo make install && \
    rm -rf /home/${USERNAME}/lib/stella_vslam

# Stella vslam ROS
RUN mkdir -p /home/${USERNAME}/stella/src && \
    source /opt/ros/${ROS_DISTRO}/setup.bash && \
    cd /home/${USERNAME}/stella/src && \
    git clone --recursive -b ros2 --depth 1 https://github.com/stella-cv/stella_vslam_ros.git && \
    cd /home/${USERNAME}/stella && \
    rosdep install -y -i --from-paths /home/${USERNAME}/stella/src --skip-keys=stella_vslam && \
    colcon build && \
    rm -rf build/ log/ src/

RUN mkdir -p /home/${USERNAME}/stella/vocab && \
    curl -L -o /home/${USERNAME}/stella/vocab/orb_vocab.fbow \
    https://raw.githubusercontent.com/stella-cv/FBoW_orb_vocab/main/orb_vocab.fbow    

# Update ldconfig
USER root
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/stella_vslam.conf && ldconfig
USER $USERNAME
