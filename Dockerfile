FROM nvcr.io/nvidia/tensorrt:20.11-py3

ENV DEBIAN_FRONTEND=noninteractive
ARG OSVER=ubuntu1804
ARG TENSORFLOWVER=2.5.0
ARG OPENVINOVER=2021.3.394
ARG OPENVINOROOTDIR=/opt/intel/openvino_2021
ARG TENSORRTVER=cuda11.1-trt7.2.1.6-ga-20201007
ARG wkdir=/home/user

# dash -> bash
RUN echo "dash dash/sh boolean false" | debconf-set-selections \
    && dpkg-reconfigure -p low dash
COPY bashrc ${wkdir}/.bashrc
WORKDIR ${wkdir}

# Install dependencies (1)
RUN apt-get update && apt-get install -y \
        automake autoconf libpng-dev nano python3-pip \
        curl zip unzip libtool swig zlib1g-dev pkg-config \
        python3-mock libpython3-dev libpython3-all-dev \
        g++ gcc cmake make pciutils cpio gosu wget \
        libgtk-3-dev libxtst-dev sudo apt-transport-https \
        build-essential gnupg git xz-utils vim \
        libva-drm2 libva-x11-2 vainfo libva-wayland2 libva-glx2 \
        libva-dev libdrm-dev xorg xorg-dev protobuf-compiler \
        openbox libx11-dev libgl1-mesa-glx libgl1-mesa-dev \
        libtbb2 libtbb-dev libopenblas-dev libopenmpi-dev \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies (2) - Ubuntu18.04: numpy==1.19.5, Ubuntu20.04: numpy>=1.20.x
RUN pip3 install --upgrade pip \
    && pip install --upgrade tensorflowjs \
    && pip install --upgrade coremltools \
    && pip install --upgrade onnx \
    && pip install --upgrade tf2onnx \
    && pip install --upgrade onnx-tf \
    && pip install --upgrade tensorflow-datasets \
    && pip install --upgrade openvino2tensorflow \
    && pip install --upgrade tflite2tensorflow \
    && pip install --upgrade onnxruntime \
    && pip install --upgrade onnx-simplifier \
    && pip install --upgrade gdown \
    && pip install --upgrade PyYAML \
    && pip install --upgrade matplotlib \
    && pip install --upgrade tf_slim \
    && pip install --upgrade numpy==1.19.5 \
    && ldconfig \
    && pip cache purge \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install custom tflite_runtime, flatc, edgetpu-compiler
RUN gdown --id 19B7BpoYVZERRh1ww04SnLelQ8dW60hvh \
    && chmod +x tflite_runtime-${TENSORFLOWVER}-cp36-none-linux_x86_64.whl \
    && pip3 install --force-reinstall tflite_runtime-${TENSORFLOWVER}-cp36-none-linux_x86_64.whl \
    && rm tflite_runtime-${TENSORFLOWVER}-cp36-none-linux_x86_64.whl \
    && gdown --id 1drnpyrXkUHsMSqb8klV2YosEU9jdoJTP \
    && tar -zxvf flatc.tar.gz \
    && chmod +x flatc \
    && rm flatc.tar.gz \
    && wget https://github.com/PINTO0309/tflite2tensorflow/raw/main/schema/schema.fbs \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | tee /etc/apt/sources.list.d/coral-edgetpu.list \
    && apt-get update \
    && apt-get install edgetpu-compiler \
    && pip cache purge \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install OpenVINO
RUN gdown --id 1GfpkEn_rnfYEYY_QzTTM2oiaCPlfbvex \
    && tar xf l_openvino_toolkit_p_${OPENVINOVER}.tgz \
    && rm l_openvino_toolkit_p_${OPENVINOVER}.tgz \
    && l_openvino_toolkit_p_${OPENVINOVER}/install_openvino_dependencies.sh -y \
    && sed -i 's/decline/accept/g' l_openvino_toolkit_p_${OPENVINOVER}/silent.cfg \
    && l_openvino_toolkit_p_${OPENVINOVER}/install.sh --silent l_openvino_toolkit_p_${OPENVINOVER}/silent.cfg \
    && source ${OPENVINOROOTDIR}/bin/setupvars.sh \
    && ${INTEL_OPENVINO_DIR}/install_dependencies/install_openvino_dependencies.sh \
    && sed -i 's/sudo -E //g' ${INTEL_OPENVINO_DIR}/deployment_tools/model_optimizer/install_prerequisites/install_prerequisites.sh \
    && sed -i 's/tensorflow/#tensorflow/g' ${INTEL_OPENVINO_DIR}/deployment_tools/model_optimizer/requirements.txt \
    && sed -i 's/numpy/#numpy/g' ${INTEL_OPENVINO_DIR}/deployment_tools/model_optimizer/requirements.txt \
    && sed -i 's/onnx/#onnx/g' ${INTEL_OPENVINO_DIR}/deployment_tools/model_optimizer/requirements.txt \
    && ${INTEL_OPENVINO_DIR}/deployment_tools/model_optimizer/install_prerequisites/install_prerequisites.sh \
    && rm -rf l_openvino_toolkit_p_${OPENVINOVER} \
    && echo "source ${OPENVINOROOTDIR}/bin/setupvars.sh" >> .bashrc \
    && echo "${OPENVINOROOTDIR}/deployment_tools/ngraph/lib/" >> /etc/ld.so.conf \
    && echo "${OPENVINOROOTDIR}/deployment_tools/inference_engine/lib/intel64/" >> /etc/ld.so.conf \
    && pip cache purge \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install TensorRT additional package
RUN gdown --id 1P4618gXcqp3X3n0RPznyen9F2XvaFZaj \
    && dpkg -i nv-tensorrt-repo-${OSVER}-${TENSORRTVER}_1-1_amd64.deb \
    && apt-key add /var/nv-tensorrt-repo-${TENSORRTVER}/7fa2af80.pub \
    && apt-get update \
    && apt-get install uff-converter-tf graphsurgeon-tf \
    && rm nv-tensorrt-repo-${OSVER}-${TENSORRTVER}_1-1_amd64.deb \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Install Custom TensorFlow (MediaPipe Custom OP, FlexDelegate, XNNPACK enabled)
RUN gdown --id 15TIFvuyiOeP4uHcXTkiw8RaacG3t1UPo \
    && pip3 install --force-reinstall tensorflow-${TENSORFLOWVER}-cp36-cp36m-linux_x86_64.whl \
    && rm tensorflow-${TENSORFLOWVER}-cp36-cp36m-linux_x86_64.whl \
    && pip cache purge \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Download the ultra-small sample data set for INT8 calibration
RUN mkdir sample_npy \
    && gdown --id 1e-Zg2OVgeTDgpndIBrwW5Ka07C5WrhSS -O sample_npy/calibration_data_img_sample.npy

# Clear caches
RUN apt clean \
    && rm -rf /var/lib/apt/lists/*

# Create a user who can sudo in the Docker container
ENV username=user
RUN echo "root:root" | chpasswd \
    && adduser --disabled-password --gecos "" "${username}" \
    && echo "${username}:${username}" | chpasswd \
    && echo "%${username}    ALL=(ALL)   NOPASSWD:    ALL" >> /etc/sudoers.d/${username} \
    && chmod 0440 /etc/sudoers.d/${username}
USER ${username}
RUN sudo chown ${username}:${username} ${wkdir}