#!/bin/bash
# 在干净的虚拟环境中完成 BirdNET TFLite → ONNX → CoreML 转换
set -e

VENV="/tmp/birdnet_venv"
MODEL="/Users/ibomb017/Library/Python/3.9/lib/python/site-packages/birdnetlib/models/analyzer/BirdNET_GLOBAL_6K_V2.4_Model_FP32.tflite"
LABELS="/Users/ibomb017/Library/Python/3.9/lib/python/site-packages/birdnetlib/models/analyzer/BirdNET_GLOBAL_6K_V2.4_Labels.txt"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="${SCRIPT_DIR}/BirdKingdom/Resources/BirdNET.mlpackage"
LABELS_DEST="${SCRIPT_DIR}/BirdKingdom/Resources/labels.txt"

echo "=== 创建虚拟环境 ==="
rm -rf "$VENV"
python3 -m venv "$VENV"
source "$VENV/bin/activate"

echo "=== 安装依赖 (兼容版本) ==="
pip install --quiet "numpy<2.0" "tensorflow==2.15.1" "tf2onnx" "coremltools==7.2" "onnx" "onnx-coreml" 2>/dev/null || \
pip install --quiet "numpy<2.0" "tensorflow==2.15.1" "tf2onnx" "coremltools==7.2" "onnx"

echo "=== Step 1: TFLite → ONNX ==="
python -m tf2onnx.convert --tflite "$MODEL" --output /tmp/birdnet.onnx --opset 13

echo "=== Step 2: ONNX → CoreML ==="
python3 << 'PYTHON'
import os, shutil
import coremltools as ct
import numpy as np

print(f"coremltools: {ct.__version__}")

# 方法1: 直接用 coremltools convert auto
onnx_path = "/tmp/birdnet.onnx"
output = os.environ.get("OUTPUT", "/tmp/BirdNET.mlpackage")

try:
    model = ct.convert(onnx_path, source="auto", minimum_deployment_target=ct.target.iOS15)
except:
    # 方法2: 用 onnx 模型对象
    import onnx
    onnx_model = onnx.load(onnx_path)
    model = ct.convert(onnx_model, minimum_deployment_target=ct.target.iOS15)

model.author = "Cornell Lab of Ornithology / BirdNET Team"
model.license = "CC BY-NC-SA 4.0"
model.short_description = "BirdNET V2.4: 6522 bird species, 3s@48kHz"
model.version = "2.4"

if os.path.exists(output):
    shutil.rmtree(output)
model.save(output)

size_mb = sum(os.path.getsize(os.path.join(dp, f)) for dp, dn, fn in os.walk(output) for f in fn) / 1024 / 1024
print(f"✅ CoreML: {output} ({size_mb:.1f}MB)")
PYTHON

# 移动到项目目录
if [ -f "/tmp/BirdNET.mlpackage/Manifest.json" ] || [ -d "/tmp/BirdNET.mlpackage" ]; then
    rm -rf "$OUTPUT"
    mv /tmp/BirdNET.mlpackage "$OUTPUT"
    echo "✅ 移动到: $OUTPUT"
fi

echo "=== Step 3: 复制标签 ==="
cp "$LABELS" "$LABELS_DEST"
wc -l "$LABELS_DEST"

echo ""
echo "🎉 转换完成！"

deactivate
