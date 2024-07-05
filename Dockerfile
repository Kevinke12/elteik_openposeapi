
# Use an official Ubuntu as a parent image
FROM runpod/pytorch:2.0.1-py3.10-cuda11.8.0-devel-ubuntu22.04

# Set non-interactive mode for apt-get and configure timezone data
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y tzdata \
    && echo 'tzdata tzdata/Areas select 8' | debconf-set-selections \
    && echo 'tzdata tzdata/Zones/8 select 11' | debconf-set-selections \
    && apt-get install -y sudo

# Update and install required packages
RUN apt-get update && apt-get install -y \
    protobuf-compiler libprotobuf-dev \
    libhdf5-dev liblmdb-dev libleveldb-dev libsnappy-dev \
    libopencv-dev libatlas-base-dev libgoogle-glog-dev \
    build-essential cmake git libboost-all-dev nano \
    wget python3-pip unzip

# Install virtualenv and create a virtual environment
RUN pip3 install virtualenv && \
    virtualenv /workspace/myenv

# Install Python dependencies
RUN /workspace/myenv/bin/pip install flask pillow numpy opencv-python

# Install cudnn
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && \
    apt-get update && \
    apt-get -y install cudnn cudnn-cuda-11

# Clone and build OpenPose
RUN git clone https://github.com/CMU-Perceptual-Computing-Lab/openpose /workspace/openpose && \
    cd /workspace/openpose && \
    git pull origin master && \
    git submodule update --init --recursive --remote && \
    mkdir build && cd build && \
    cmake -DBUILD_PYTHON=ON .. && \
    cmake -DBUILD_PYTHON=ON .. && \
    make -j$(nproc)

# Download additional files
RUN wget --no-check-certificate -O /workspace/runpod.py https://baginf.hu/ELTE_IK_RobotDemoInstallFolder/runpod.py && \
    wget --no-check-certificate -O /workspace/openpose/models/pose/body_25/pose_deploy.prototxt https://baginf.hu/ELTE_IK_RobotDemoInstallFolder/pose_deploy.prototxt && \
    wget --no-check-certificate -O /workspace/openpose/models/pose/body_25/pose_iter_584000.caffemodel https://baginf.hu/ELTE_IK_RobotDemoInstallFolder/pose_iter_584000.caffemodel && \
    wget --no-check-certificate -O /workspace/klaszteradat.zip https://baginf.hu/ELTE_IK_RobotDemoInstallFolder/klaszteradat.zip && \
    unzip /workspace/klaszteradat.zip -d /workspace/

# Export OpenPose API to PYTHONPATH
ENV PYTHONPATH /workspace/openpose/build/python/openpose:${PYTHONPATH}

# Test OpenPose Python API
RUN /workspace/myenv/bin/python -c "import pyopenpose as op; print('OpenPose Python API is working')"

# Set the entrypoint to run the worker script
ENTRYPOINT ["/bin/bash", "-c", "source /workspace/myenv/bin/activate && python3 /workspace/runpod.py"]
