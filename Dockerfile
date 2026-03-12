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

# Install LLVM/Clang 19
RUN bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)" -- 19

# Pin clang / clang++ to version 19
RUN ln -sf /usr/bin/clang-19 /usr/bin/clang && \
    ln -sf /usr/bin/clang++-19 /usr/bin/clang++

# Clone BitNet
RUN git clone --recursive https://github.com/microsoft/BitNet.git /app

# Create isolated Python environment
RUN python3 -m venv /opt/bitnet-venv
ENV PATH="/opt/bitnet-venv/bin:$PATH"

# Install Python deps inside venv
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt && \
    pip install huggingface_hub

# Download official model
RUN huggingface-cli download microsoft/BitNet-b1.58-2B-4T-gguf --local-dir /app/models/BitNet-b1.58-2B-4T

# Prepare BitNet environment and print logs if compile fails
RUN python setup_env.py -md /app/models/BitNet-b1.58-2B-4T -q i2_s || (echo "===== generate_build_files.log =====" && cat logs/generate_build_files.log && echo "===== compile.log =====" && cat logs/compile.log && false)

EXPOSE 8080

CMD ["bash", "-lc", "python run_inference_server.py -m /app/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf --host 0.0.0.0 --port 8080 -t $(nproc) -c 2048 -n 512"]
