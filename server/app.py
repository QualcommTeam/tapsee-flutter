from flask import Flask, request, jsonify
import subprocess
import os

app = Flask(__name__)

@app.route('/ocr', methods=['POST'])
def ocr():
   # 1) Save incoming image

    file = request.files.get('image')
    if not file:
        return jsonify({'error': 'No image provided'}), 400

    save_dir = os.path.join(os.getcwd(), 'uploads')
    os.makedirs(save_dir, exist_ok=True)
    save_path = os.path.join(save_dir, file.filename)
    file.save(save_path)

    # 2) qnn-net-run 호출
    out_dir = os.path.join(os.getcwd(), 'ocr_out')
    os.makedirs(out_dir, exist_ok=True)
    cmd = [
        'qnn-net-run',
        '--model', r'C:\path\to\detector.bin',       # ← 실제 경로로 수정
        '--backend', r'C:\path\to\libQnnCpu.so',     # ← 실제 경로로 수정
        '--input_list', save_path,
        '--output_dir', out_dir
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)

    # 3) 결과 JSON 반환
    return jsonify({
        'stdout': result.stdout,
        'stderr': result.stderr,
        'outputs': os.listdir(out_dir)
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
