FROM ghcr.io/uoy-robostar/ros2-tb3:main

# Install pangolin dependencies
# RUN sudo apt update && sudo apt install -y curl zip unzip tar nasm

# RUN git clone https://github.com/Microsoft/vcpkg.git \
#     cd vcpkg \
#     ./bootstrap-vcpkg.sh -disableMetrics \
#     ./vcpkg integrate install \
#     ./vcpkg install pangolin \

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