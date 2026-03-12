FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

WORKDIR /app

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
    && rm -rf /var/lib/apt/lists/*

# Install LLVM/Clang
RUN bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"

# Point clang / clang++ to the newest installed version
RUN CLANG_BIN="$(ls /usr/bin/clang-[0-9]* | sort -V | tail -n1)" && \
    CLANGXX_BIN="$(ls /usr/bin/clang++-[0-9]* | sort -V | tail -n1)" && \
    ln -sf "$CLANG_BIN" /usr/bin/clang && \
    ln -sf "$CLANGXX_BIN" /usr/bin/clang++

# Clone BitNet
RUN git clone --recursive https://github.com/microsoft/BitNet.git /app

# Install Python deps
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip3 install -r requirements.txt && \
    pip3 install huggingface_hub

# Download model
RUN huggingface-cli download microsoft/BitNet-b1.58-2B-4T-gguf --local-dir /app/models/BitNet-b1.58-2B-4T

# Prepare environment
RUN python3 setup_env.py -md /app/models/BitNet-b1.58-2B-4T -q i2_s

EXPOSE 8080

CMD ["bash", "-lc", "python3 run_inference_server.py -m /app/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf --host 0.0.0.0 --port 8080 -t $(nproc) -c 2048 -n 512"]
