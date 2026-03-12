FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# Base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    python3 \
    python3-pip \
    python3-venv \
    cmake \
    build-essential \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Install LLVM/Clang 18 (BitNet needs clang >= 18)
RUN bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)" -- 18 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    clang-18 \
    lld-18 \
    lldb-18 \
    clangd-18 \
    libomp-18-dev \
    && rm -rf /var/lib/apt/lists/*

# Make clang-18 default
RUN ln -sf /usr/bin/clang-18 /usr/bin/clang && \
    ln -sf /usr/bin/clang++-18 /usr/bin/clang++

ENV CC=/usr/bin/clang
ENV CXX=/usr/bin/clang++
ENV PATH="/opt/bitnet-venv/bin:${PATH}"

# Clone BitNet
RUN git clone --recursive https://github.com/microsoft/BitNet.git /app

# Patch the clang const-qualification compile error seen in ggml-bitnet-mad.cpp
RUN perl -0pi -e 's/int8_t \* y_col = y \+ col \* by;/const int8_t * y_col = y + col * by;/g' /app/src/ggml-bitnet-mad.cpp

# Python virtualenv
RUN python3 -m venv /opt/bitnet-venv

# Python deps
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt && \
    pip install huggingface_hub

# Download official BitNet 2B GGUF model
RUN hf download microsoft/BitNet-b1.58-2B-4T-gguf \
    --local-dir /app/models/BitNet-b1.58-2B-4T

# Build BitNet environment
RUN python setup_env.py -md /app/models/BitNet-b1.58-2B-4T -q i2_s || \
    (echo "===== generate_build_files.log =====" && cat logs/generate_build_files.log && \
     echo "===== compile.log =====" && cat logs/compile.log && false)

EXPOSE 8080

# Start inference server
CMD ["python", "run_inference_server.py", \
     "-m", "/app/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf", \
     "--host", "0.0.0.0", \
     "--port", "8080", \
     "-t", "4", \
     "-c", "2048", \
     "-n", "512"]
