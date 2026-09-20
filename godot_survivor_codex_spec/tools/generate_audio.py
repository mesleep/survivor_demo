"""生成原创庭院芯片乐与短音效；仅使用标准库，输出单声道 PCM。"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def save(name, notes, beat, music=False):
    samples = []
    for index, midi in enumerate(notes):
        frequency = 440 * 2 ** ((midi - 69) / 12)
        for frame in range(int(RATE * beat)):
            t = frame / RATE
            envelope = min(t / 0.008, 1) * max(0, 1 - t / beat) ** 1.8
            value = math.sin(math.tau * frequency * t)
            value += 0.2 * math.sin(math.tau * frequency * 2 * t)
            if music:
                bass = [48, 53, 57, 55][index // 8 % 4]
                value += 0.35 * math.sin(math.tau * 440 * 2 ** ((bass - 69) / 12) * t)
            samples.append(struct.pack('<h', int(value * envelope * 8500)))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(b''.join(samples))


OUT.mkdir(parents=True, exist_ok=True)
save('星光发射', [84, 76], 0.045)
save('宝石拾取', [88, 95], 0.055)
save('轻巧击退', [60, 48], 0.055)
save('升级铃声', [72, 76, 79, 84], 0.12)
save('守护成功', [72, 76, 79, 84, 79, 84, 88, 91], 0.15)
save('休息时刻', [72, 67, 64, 60], 0.22)
save('领主出现', [48, 48, 55, 60], 0.17)
save('月光散步', [72, 76, 79, 76, 74, 72, 67, 71,
                 69, 72, 77, 76, 72, 69, 65, 69,
                 69, 72, 76, 79, 76, 72, 69, 72,
                 71, 74, 79, 77, 74, 71, 67, 71] * 2, 0.3, True)
