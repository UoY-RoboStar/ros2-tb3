# syntax=docker/dockerfile:1.10.0

# osrf/ros:lyrical-desktop-full is amd64-only, so we build on the multi-arch
# ros:lyrical-ros-base image (amd64 + arm64) and apt-install desktop/perception ourselves.
FROM ros:lyrical-ros-base

# Populated automatically by buildx (e.g. "amd64", "arm64")
ARG TARGETARCH

# ROS's setup.bash uses bash-only syntax, so it can't be sourced under the default
# /bin/sh (dash); switch the build shell to bash for the rest of the Dockerfile.
SHELL ["/bin/bash", "-c"]

# Run everything as root instead of creating a non-root user. This image is mainly used
# rootless under Podman, where root inside the container is already remapped to the
# invoking host user by default - a separate non-root user only adds a second UID that
# then needs its own reconciliation with the host for bind-mounted files (e.g.
# .Xauthority) and device nodes (e.g. /dev/dri). Doing that reconciliation through the
# VS Code Dev Containers CLI turned out to be unreliable: Podman's --userns=keep-id
# suboption syntax isn't accepted by its Docker-compatible CLI shim, and even the plain
# form conflicts with named volumes created under the default mapping. USERNAME is kept
# purely as the home directory name, so the rest of this Dockerfile doesn't need to change.
ARG USERNAME=ubuntu
ENV HOME=/home/${USERNAME}

# Install alsa-utils so we can setup null plugin. apt update is needed here since removing
# the old non-root-user/sudo setup also removed the apt-get update that used to run as a
# side effect of installing the sudo package before this step.
RUN apt update && apt install -y alsa-utils
RUN echo 'pcm.!default { type null }' >> /etc/asound.conf

# Update all packages
RUN apt update && apt upgrade -y

# Install Git and other utilities
RUN apt install -y git psmisc wget acl software-properties-common lxterminal

# Since the container runs as root, git refuses to touch the bind-mounted workspace
# unless its ownership is explicitly trusted: under a real rootful Docker daemon (Docker
# Desktop on Windows/WSL2 and macOS - not rootless Podman, where root is already remapped
# to the host user) the mounted repo is owned by the host user rather than root, and git
# treats that mismatch as "dubious ownership" and refuses every command.
RUN git config --system --add safe.directory '*'

# Install the ROS desktop packages (rviz2, demos, perception, ...) that used to
# come from the osrf/ros:lyrical-desktop-full base image. We deliberately install
# ros-lyrical-desktop + ros-lyrical-perception rather than ros-lyrical-desktop-full: the
# "-full" metapackage also pulls in ros-lyrical-simulation, which includes simulators
# this project doesn't use (e.g. Webots bridges) - ros-lyrical-turtlebot3-gazebo below
# already pulls in exactly the ros_gz/Gazebo Harmonic packages TurtleBot3 needs.
RUN apt update && apt install -y ros-lyrical-desktop ros-lyrical-perception

# Add Open Robotics' Gazebo apt repo. ros-lyrical-turtlebot3-gazebo depends on the
# gz-harmonic system libraries, which are published on packages.osrfoundation.org,
# not packages.ros.org - without this repo those dependencies fail to resolve.
RUN apt install -y lsb-release wget gnupg && \
    wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null

# Install Turtlebot3. ros-lyrical-turtlebot3, -turtlebot3-navigation2 and -turtlebot3-teleop
# aren't published on packages.ros.org yet (Lyrical is only a few months old as of this
# writing) - checked against the actual apt Packages index, not just index.ros.org's
# rosdistro-release status, which runs ahead of what the buildfarm has actually built.
# turtlebot3_navigation2/_cartographer/_node in turn need nav2_bringup, cartographer_ros and
# hls_lfcd_lds_driver, which are missing too - but everything else those three need (the rest
# of the nav2 stack, cartographer_ros_msgs, etc.) is already published, so only these four
# repos are built from source, into one workspace so colcon resolves the cross-package
# dependencies together. ros-lyrical-dynamixel-sdk and ros-lyrical-turtlebot3-msgs are separate
# repos that are already published, so those still come from apt. nav2_bringup's CMakeLists.txt
# also does a hard find_package(navigation2) for the umbrella metapackage, but never uses
# anything from it (nav2_bringup is just launch files/configs, no C++) - the package itself
# would also drag in nav2-smac-planner, which isn't published either, so rather than build the
# whole metapackage from source the unused find_package() call is just patched out.
# hls_lfcd_lds_driver's find_package(Boost REQUIRED system) is patched the same way: Boost on
# this base image (1.90) no longer ships boost_system as a separate compiled library (it's been
# header-only for years), so requesting that CMake component fails outright. Its source also
# still uses boost::asio::io_service, removed from Boost.Asio years ago in favour of the
# API-compatible io_context - swapped in with a plain rename. turtlebot3_node's `main` branch
# similarly hasn't caught up with the .h -> .hpp header renames that message_filters and tf2's
# LinearMath classes went through (same move cv_bridge already made, see the stella_vslam_ros
# patch below) - patched the same way, across the whole workspace in case anything else built
# here hits the same two renames. It also calls message_filters::Subscriber's old two-argument
# (node, topic) constructor, which current message_filters removed in favour of always requiring
# an explicit QoS - patched to pass the queue_size already in scope at both call sites.
# cartographer-project/cartographer itself is unmaintained (no real release since ~2021) and its
# CMakeLists/Ceres usage no longer builds against current toolchains at all - ros2/cartographer
# and ros2/cartographer_ros (the forks the ROS buildfarm actually releases jazzy/kilted from, see
# https://github.com/ros2/cartographer) carry the fixes upstream never merged, so those are used
# instead, on their `ros2` branch. cartographer_ros itself comes from the UoY-RoboStar fork's
# `lyrical` branch instead: node_main.cpp and offline_node.cpp both DEFINE_bool a gflag named
# collect_metrics, and since offline_node.cpp compiled into the shared library cartographer_node
# also links against, cartographer_node ended up with the same gflag defined twice in one process
# and aborted at startup - fixed upstream on this branch by compiling offline_node.cpp directly
# into cartographer_offline_node instead of the shared library (matching
# https://github.com/ros2/cartographer_ros/pull/84, open against
# https://github.com/ros2/cartographer_ros/issues/80 but not yet merged). Even that fork still
# uses the old unprefixed thread-safety-
# analysis macro names (GUARDED_BY, LOCKS_EXCLUDED, ...) that Abseil used to alias for
# compatibility; recent Abseil only defines the ABSL_-prefixed versions now. Rather than patch
# macro names
# across the whole cartographer source tree, force-include a small header (matching how Abseil
# itself defines these as no-ops on non-Clang compilers, which is what GCC here is) ahead of
# every translation unit in this workspace.
RUN cat <<'EOF' > /usr/local/include/legacy_thread_annotations_compat.h
#ifndef GUARDED_BY
#define GUARDED_BY(x)
#endif
#ifndef PT_GUARDED_BY
#define PT_GUARDED_BY(x)
#endif
#ifndef ACQUIRED_AFTER
#define ACQUIRED_AFTER(...)
#endif
#ifndef ACQUIRED_BEFORE
#define ACQUIRED_BEFORE(...)
#endif
#ifndef EXCLUSIVE_LOCKS_REQUIRED
#define EXCLUSIVE_LOCKS_REQUIRED(...)
#endif
#ifndef SHARED_LOCKS_REQUIRED
#define SHARED_LOCKS_REQUIRED(...)
#endif
#ifndef LOCKS_EXCLUDED
#define LOCKS_EXCLUDED(...)
#endif
#ifndef LOCK_RETURNED
#define LOCK_RETURNED(x)
#endif
#ifndef LOCKABLE
#define LOCKABLE
#endif
#ifndef SCOPED_LOCKABLE
#define SCOPED_LOCKABLE
#endif
#ifndef EXCLUSIVE_LOCK_FUNCTION
#define EXCLUSIVE_LOCK_FUNCTION(...)
#endif
#ifndef SHARED_LOCK_FUNCTION
#define SHARED_LOCK_FUNCTION(...)
#endif
#ifndef UNLOCK_FUNCTION
#define UNLOCK_FUNCTION(...)
#endif
#ifndef EXCLUSIVE_TRYLOCK_FUNCTION
#define EXCLUSIVE_TRYLOCK_FUNCTION(...)
#endif
#ifndef SHARED_TRYLOCK_FUNCTION
#define SHARED_TRYLOCK_FUNCTION(...)
#endif
#ifndef ASSERT_EXCLUSIVE_LOCK
#define ASSERT_EXCLUSIVE_LOCK(...)
#endif
#ifndef ASSERT_SHARED_LOCK
#define ASSERT_SHARED_LOCK(...)
#endif
#ifndef NO_THREAD_SAFETY_ANALYSIS
#define NO_THREAD_SAFETY_ANALYSIS
#endif
EOF
RUN apt update && apt install -y ros-lyrical-dynamixel-sdk ros-lyrical-turtlebot3-msgs
# nav2_bringup's package.xml only exec_depends on the "navigation2" umbrella metapackage (see
# --skip-keys=navigation2 below) rather than on the individual nav2-* packages it actually needs
# at runtime (nav2_bt_navigator, nav2_controller, nav2_planner, ...) - those were never getting
# installed, since they were only ever pulled in transitively through that umbrella. Installed
# explicitly here instead, checked directly against the umbrella's own exec_depend list. Every
# entry in that list is published for lyrical except nav2-smac-planner, which is left out; the
# other planner plugins (navfn, theta-star, regulated-pure-pursuit, mppi) are all present.
RUN apt update && apt install -y \
        ros-lyrical-nav2-amcl \
        ros-lyrical-nav2-behavior-tree \
        ros-lyrical-nav2-behaviors \
        ros-lyrical-nav2-bt-navigator \
        ros-lyrical-nav2-collision-monitor \
        ros-lyrical-nav2-constrained-smoother \
        ros-lyrical-nav2-controller \
        ros-lyrical-nav2-core \
        ros-lyrical-nav2-costmap-2d \
        ros-lyrical-nav2-dwb-controller \
        ros-lyrical-nav2-graceful-controller \
        ros-lyrical-nav2-lifecycle-manager \
        ros-lyrical-nav2-loopback-sim \
        ros-lyrical-nav2-map-server \
        ros-lyrical-nav2-mppi-controller \
        ros-lyrical-nav2-msgs \
        ros-lyrical-nav2-navfn-planner \
        ros-lyrical-nav2-planner \
        ros-lyrical-nav2-regulated-pure-pursuit-controller \
        ros-lyrical-nav2-ros-common \
        ros-lyrical-nav2-rotation-shim-controller \
        ros-lyrical-nav2-route \
        ros-lyrical-nav2-rviz-plugins \
        ros-lyrical-nav2-simple-commander \
        ros-lyrical-nav2-smoother \
        ros-lyrical-nav2-theta-star-planner \
        ros-lyrical-nav2-util \
        ros-lyrical-nav2-velocity-smoother \
        ros-lyrical-nav2-voxel-grid \
        ros-lyrical-nav2-waypoint-follower \
        ros-lyrical-opennav-docking \
        ros-lyrical-opennav-docking-bt \
        ros-lyrical-opennav-docking-core \
        ros-lyrical-opennav-following
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    mkdir -p /home/${USERNAME}/tb3_ws/src && \
    cd /home/${USERNAME}/tb3_ws/src && \
    git clone -b main https://github.com/ROBOTIS-GIT/turtlebot3.git && \
    git clone -b main https://github.com/ROBOTIS-GIT/hls_lfcd_lds_driver.git && \
    sed -i "s/find_package(Boost REQUIRED system)/find_package(Boost REQUIRED)/" hls_lfcd_lds_driver/CMakeLists.txt && \
    sed -i "s/io_service/io_context/g" \
        hls_lfcd_lds_driver/include/hls_lfcd_lds_driver/lfcd_laser.hpp \
        hls_lfcd_lds_driver/src/hlds_laser_publisher.cpp && \
    git clone -b ros2 https://github.com/ros2/cartographer.git && \
    git clone --no-checkout -b lyrical https://github.com/UoY-RoboStar/cartographer_ros.git cartographer_ros && \
    (cd cartographer_ros && git sparse-checkout init --cone && git sparse-checkout set cartographer_ros && git checkout lyrical) && \
    git clone --no-checkout -b lyrical https://github.com/ros-navigation/navigation2.git navigation2 && \
    (cd navigation2 && git sparse-checkout init --cone && git sparse-checkout set nav2_bringup && git checkout lyrical) && \
    sed -i "/find_package(navigation2 REQUIRED)/d" navigation2/nav2_bringup/CMakeLists.txt && \
    find . -type f \( -name '*.cpp' -o -name '*.hpp' -o -name '*.h' \) \
        -exec sed -i -E 's#(message_filters/[A-Za-z_/]+|tf2/LinearMath/[A-Za-z_]+)\.h([>"])#\1.hpp\2#g' {} + && \
    sed -i \
        -e 's/"joint_states");/"joint_states", rclcpp::QoS(queue_size));/' \
        -e 's/"imu");/"imu", rclcpp::QoS(queue_size));/' \
        turtlebot3/turtlebot3_node/src/odometry.cpp && \
    cd /home/${USERNAME}/tb3_ws && \
    rosdep install -r --from-paths . --ignore-src --rosdistro ${ROS_DISTRO} -y --skip-keys=navigation2 && \
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_CXX_FLAGS=-include\ /usr/local/include/legacy_thread_annotations_compat.h \
        --parallel-workers $(($(nproc) / 2)) && \
    rm -rf build/ log/ src/*/.git && \
    echo "source /home/${USERNAME}/tb3_ws/install/setup.bash" >> /home/${USERNAME}/.bashrc

# Install the Gazebo Harmonic/Turtlebot3 simulation integration from apt. Unlike Humble
# (where these were amd64-only binaries, forcing a from-source build on every
# architecture), ros-lyrical-turtlebot3-gazebo and ros-lyrical-gz-ros2-control are published
# for both amd64 and arm64, following
# https://docs.robotis.com/docs/systems/turtlebot3/simulation/gazebo_simulation
RUN apt update && apt install -y ros-lyrical-turtlebot3-gazebo ros-lyrical-gz-ros2-control

# Install rtabmap-ros
RUN apt update && apt install -y ros-lyrical-rtabmap-ros

# Install movit2
RUN apt update && apt install -y ros-lyrical-moveit ros-lyrical-moveit-resources-panda-moveit-config

# Install RMW CycloneDDS
# RUN apt install -y ros-lyrical-rmw-cyclonedds-cpp

# Install useful Python3 packages
RUN apt install -y python3-pip python3-rosdep python3-argcomplete python3-transforms3d

# Install mesa utils
RUN apt update && apt install -y mesa-utils

# Install OpenCL for Intel (amd64 only; intel-opencl-icd isn't published for arm64)
RUN apt update && apt install -y clinfo && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        apt install -y intel-opencl-icd; \
    fi

# Fix fluxbox environment
RUN mkdir -p /home/$USERNAME/.fluxbox/styles
COPY fluxbox/init /home/$USERNAME/.fluxbox/init
COPY fluxbox/menu /home/$USERNAME/.fluxbox/menu
COPY fluxbox/qnx-photon-mod /home/$USERNAME/.fluxbox/styles/qnx-photon-mod

# Rosdep update
RUN rosdep update

# Ignore warning for colcon builds
RUN echo 'export PYTHONWARNINGS=ignore:::setuptools.command.install,ignore:::setuptools.command.easy_install,ignore:::pkg_resources' >> ~/.bashrc

# Colcon_cd. python3-colcon-cd on this base image's Ubuntu release ("resolute") ships its
# shell function at /etc/profile.d/colcon_cd.sh rather than the
# /usr/share/colcon_cd/function/colcon_cd.sh path used in ROS's own tutorials/older
# packaging, which is why sourcing that path failed with "No such file or directory".
RUN echo "source /etc/profile.d/colcon_cd.sh" >> ~/.bashrc
RUN echo "export _colcon_cd_root=/opt/ros/${ROS_DISTRO}/" >> ~/.bashrc

# Colcon auto-complete
RUN echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash" >> ~/.bashrc

# Set default RMW implementation
# RUN echo 'export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp' >> ~/.bashrc

# Set default turtlebot3 model
RUN echo 'export TURTLEBOT3_MODEL=waffle_pi' >> ~/.bashrc

# Source the ROS setup file
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc

# Install useful Python3 packages from pip as user. Ubuntu 24.04 marks the system Python as
# externally-managed (PEP 668) and refuses a plain `pip install`, so these go into a venv
# instead - built with --system-site-packages so ROS's own python packages (e.g. rclpy) stay
# visible, and activated from ~/.bashrc so interactive shells get both automatically.
RUN apt install -y python3-venv
RUN python3 -m venv --system-site-packages /home/${USERNAME}/.venv
RUN /home/${USERNAME}/.venv/bin/pip install gdown pydantic angles transitions python-statemachine
RUN echo "source /home/${USERNAME}/.venv/bin/activate" >> ~/.bashrc

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
# help; the second apt remove is the actual fix. On lyrical that Kinova rosdep key isn't
# published at all yet, so rosdep is also told to skip it outright rather than fail the build;
# the double apt remove is left in place regardless, since it's still the real fix if apt ever
# does pull the moveit binaries back in for some other reason.
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    mkdir -p /home/${USERNAME}/ws_moveit/src && \
    cd /home/${USERNAME}/ws_moveit/src && \
    colcon --log-base /dev/null mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon --log-base /dev/null mixin update default && \
    git clone -b main https://github.com/moveit/moveit2_tutorials && \
    vcs import --recursive < moveit2_tutorials/moveit2_tutorials.repos && \
    rm -rf ros2_kortex ros2_robotiq_gripper serial && \
    apt remove ros-$ROS_DISTRO-moveit* -y && \
    apt update && rosdep install -r --from-paths . --ignore-src --rosdistro $ROS_DISTRO -y \
        --skip-keys=kinova_gen3_7dof_robotiq_2f_85_moveit_config && \
    apt remove ros-$ROS_DISTRO-moveit* -y && \
    cd /home/${USERNAME}/ws_moveit/ && \
    colcon build --mixin release && \
    rm -rf build/ log/ src/ && \
    echo "source /home/${USERNAME}/ws_moveit/install/setup.bash" >> ~/.bashrc

# Install ARGoS3 simulator. The upstream project only publishes x86_64 packages, so this
# uses UoY-RoboStar's own build (https://github.com/UoY-RoboStar/argos3/releases), which
# publishes .debs for both amd64 and arm64.
RUN if [ "$TARGETARCH" = "arm64" ]; then ARGOS3_ARCH=aarch64; else ARGOS3_ARCH=x86_64; fi && \
    curl -fsSL -o /home/${USERNAME}/argos3_simulator-3.0.0-${ARGOS3_ARCH}-beta59.deb \
        "https://github.com/UoY-RoboStar/argos3/releases/download/3.0.0-beta59/argos3_simulator-3.0.0-${ARGOS3_ARCH}-beta59.deb" && \
    apt update && apt install -y /home/${USERNAME}/argos3_simulator-3.0.0-${ARGOS3_ARCH}-beta59.deb && \
    rm /home/${USERNAME}/argos3_simulator-3.0.0-${ARGOS3_ARCH}-beta59.deb && \
    # The aarch64 .deb installs under /usr/local instead of /usr (unlike the x86_64 one).
    # argos3-ros2-bridge's plugins/bridge/CMakeLists.txt hardcodes /usr/lib/argos3/*.so as
    # link targets, so symlink it into place if the package installed elsewhere.
    if [ ! -e /usr/lib/argos3 ] && [ -d /usr/local/lib/argos3 ]; then ln -s /usr/local/lib/argos3 /usr/lib/argos3; fi

# Install ARGoS3 examples and build them
RUN git clone https://github.com/ilpincy/argos3-examples.git /home/${USERNAME}/argos3-examples && \
    mkdir -p /home/${USERNAME}/argos3-examples/build && \
    cd /home/${USERNAME}/argos3-examples/build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make

# Install GSL libraries. Package name follows the GSL SONAME, which this base image's newer
# Ubuntu ("resolute") has bumped to 28 (it was libgsl27 on jazzy's Ubuntu 24.04 base).
RUN apt update && apt install -y libgsl28 libgsl-dev

# Install ARGos3 ROS2 bridge (depends on ARGoS3 above), from the `lyrical` branch - main's
# CMakeLists.txt predates this base image's CMake, which has dropped support for
# cmake_minimum_required() versions below 3.5, and plugins/bridge/CMakeLists.txt called the
# ament_target_dependencies() macro, which current ament_cmake no longer provides at all (fixed
# upstream on this branch by linking the modern CMake targets directly instead).
RUN --mount=type=secret,id=GIT_AUTH_TOKEN,env=GIT_AUTH_TOKEN \
    export OpenGL_GL_PREFERENCE=GLVND && \
    mkdir -p /home/${USERNAME}/bridge_ws/src && \
    git clone -b lyrical https://${GIT_AUTH_TOKEN}@github.com/UoY-RoboStar/argos3-ros2-bridge.git /home/${USERNAME}/bridge_ws/src/argos3-ros2-bridge && \
    cd /home/${USERNAME}/bridge_ws && \
    source /opt/ros/${ROS_DISTRO}/setup.bash && \
    colcon build --packages-select argos3_ros2_bridge --cmake-args -DCMAKE_POLICY_VERSION_MINIMUM=3.5 && \
    colcon build --packages-select argos3_ros2_bridge --cmake-args -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DFIRST_TIME=Off && \
    echo "export ARGOS_PLUGIN_PATH=/home/${USERNAME}/argos3-examples:/home/${USERNAME}/bridge_ws/install/argos3_ros2_bridge/lib:\$ARGOS_PLUGIN_PATH" >> ~/.bashrc && \
    echo "export LD_LIBRARY_PATH=\$ARGOS_PLUGIN_PATH:\$LD_LIBRARY_PATH" >> ~/.bashrc && \
    echo "source /home/${USERNAME}/bridge_ws/install/local_setup.bash" >> ~/.bashrc

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

# Install pangolin dependencies and other required packages
RUN apt update && apt install -y libglew-dev ffmpeg unzip

# Pangolin. Pinned to an old commit that already needs the two source patches below, so - like
# cartographer and argos3_ros2_bridge above - -DCMAKE_POLICY_VERSION_MINIMUM=3.5 is added here
# and to the Iridescence/Stella VSLAM builds below pre-emptively rather than one CI round-trip
# at a time; it's a no-op for any CMakeLists.txt that's already compliant. Same reasoning for the
# missing <cstdint> include below: only image_io_packed12bit.cpp hit it in CI (this old snapshot
# relies on the header coming in transitively, which current libstdc++ no longer guarantees), but
# scanning the tree found dozens of other files with the same latent gap - most are disabled by
# the BUILD_PANGOLIN_*=OFF flags below and would never actually surface it, but fixing every file
# that uses a fixed-width int type without including it directly is a no-op for the excluded ones
# and avoids finding the rest one CI run at a time.
RUN cd /home/${USERNAME}/ && \
    git clone https://github.com/stevenlovegrove/Pangolin.git && \
    cd Pangolin && \
    git checkout ad8b5f83 && \
    sed -i -e "193,198d" ./src/utils/file_utils.cpp && \
    grep -rlE '\b(u?int(8|16|32|64)_t)\b' --include='*.cpp' --include='*.h' --include='*.hpp' src include | \
        xargs grep -L -E '#include[[:space:]]*[<"](cstdint|stdint\.h)[>"]' | \
        xargs -r sed -i '1i #include <cstdint>' && \
    mkdir -p build && \
    cd build && \
    cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
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
    make install && \
    cd / && rm -rf Pangolin

# Iridescence. src/guik/viewer/info_window.cpp uses Boost.Process's classic API
# (boost::process::ipstream/child/std_out), which Boost 1.87+ moved behind an explicit
# boost::process::v1:: namespace as part of the v2 redesign (no macro opt-in exists to keep the
# unqualified names) - patched to include the v1 header and qualify every boost::process:: use.
RUN apt update && apt install -y libglm-dev libglfw3-dev libpng-dev libjpeg-dev libeigen3-dev libboost-filesystem-dev libboost-program-options-dev && \
    cd /home/${USERNAME}/ && \
    git clone https://github.com/koide3/iridescence.git && \
    cd iridescence && \
    git checkout 085322e0c949f75b67d24d361784e85ad7f197ab && \
    sed -i \
        -e '/#include <boost\/process.hpp>/a #include <boost/process/v1.hpp>' \
        -e 's/boost::process::/boost::process::v1::/g' \
        src/guik/viewer/info_window.cpp && \
    git submodule update --init --recursive && \
    mkdir -p build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .. && \
    make -j"$(($(nproc)/2))" && \
    make install && \
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
    cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .. && \
    make -j"$(($(nproc)/2))" && \
    make install && \
    rm -rf /home/${USERNAME}/lib/stella_vslam

# Stella vslam ROS, from the UoY-RoboStar fork's `lyrical` branch - upstream's CMakeLists.txt
# (both the root one and src/CMakeLists.txt) call the now-fully-removed ament_target_dependencies()
# (see the ARGoS3 bridge notes above), and stella_vslam_ros.h uses the pre-rename message_filters
# and cv_bridge headers (see the message_filters/tf2 notes above) - both fixed upstream on this
# branch, along with a redundant explicit ament_environment_hooks(LIBRARY_PATH) registration that
# current CMake turns into a hard configure-time error.
RUN mkdir -p /home/${USERNAME}/stella/src && \
    source /opt/ros/${ROS_DISTRO}/setup.bash && \
    cd /home/${USERNAME}/stella/src && \
    git clone --recursive -b lyrical --depth 1 https://github.com/UoY-RoboStar/stella_vslam_ros.git && \
    cd /home/${USERNAME}/stella && \
    rosdep install -y -i --from-paths /home/${USERNAME}/stella/src --skip-keys=stella_vslam && \
    colcon build --cmake-args -DCMAKE_POLICY_VERSION_MINIMUM=3.5 && \
    rm -rf build/ log/ src/

RUN mkdir -p /home/${USERNAME}/stella/vocab && \
    curl -L -o /home/${USERNAME}/stella/vocab/orb_vocab.fbow \
    https://raw.githubusercontent.com/stella-cv/FBoW_orb_vocab/main/orb_vocab.fbow    

# Update ldconfig
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/stella_vslam.conf && ldconfig
