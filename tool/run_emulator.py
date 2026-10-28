#!/usr/bin/env python3
"""Open the existing JLPT Android app on this Linux PC, preserving its data."""
import os
from pathlib import Path
import socket
import subprocess
import time
import fcntl


def main():
    project = Path(__file__).resolve().parents[1]
    runtime = Path.home() / '.local/share/jlpt-study'
    sdk = Path(os.environ.get('JLPT_ANDROID_SDK', runtime / 'android-sdk'))
    avd = os.environ.get('JLPT_AVD_NAME', 'jlpt_test_device')
    adb = sdk / 'platform-tools/adb'
    emulator = sdk / 'emulator/emulator'
    apk = project / 'dist/jlpt-study-debug.apk'
    for required in (adb, emulator, apk):
        if not required.is_file():
            raise SystemExit(f'파일을 찾을 수 없습니다: {required}\nREADME의 Linux 에뮬레이터 안내를 확인해주세요.')
    runtime.mkdir(parents=True, exist_ok=True)
    with (runtime / 'launcher.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('에뮬레이터를 이미 시작하고 있습니다. 잠시 기다려주세요.')
            return

        def call(*arguments, check=True):
            return subprocess.run([str(adb), *arguments], capture_output=True,
                                  text=True, timeout=60, check=check)

        serial = None
        for line in call('devices').stdout.splitlines()[1:]:
            fields = line.split()
            if fields and fields[0].startswith('emulator-'):
                result = call('-s', fields[0], 'emu', 'avd', 'name', check=False)
                if avd in result.stdout.splitlines():
                    serial = fields[0]
                    break
        process = None
        if serial is None:
            port = None
            for candidate in range(5554, 5584, 2):
                try:
                    with socket.socket() as console, socket.socket() as debug:
                        console.bind(('127.0.0.1', candidate))
                        debug.bind(('127.0.0.1', candidate + 1))
                    port = candidate
                    break
                except OSError:
                    continue
            if port is None:
                raise SystemExit('사용할 수 있는 에뮬레이터 포트가 없습니다.')
            serial = f'emulator-{port}'
            environment = dict(os.environ, ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk))
            with (runtime / 'emulator.log').open('w') as log:
                process = subprocess.Popen(
                    [str(emulator), '-avd', avd, '-port', str(port), '-gpu', 'swiftshader',
                     '-no-snapshot', '-no-boot-anim', '-no-metrics'],
                    env=environment, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            print('안드로이드를 시작하고 있습니다…', flush=True)
        for _ in range(180):
            if process is not None and process.poll() is not None:
                raise SystemExit(f'에뮬레이터가 종료됐습니다. 로그: {runtime / "emulator.log"}')
            if call('-s', serial, 'shell', 'getprop', 'sys.boot_completed', check=False).stdout.strip() == '1':
                break
            time.sleep(1)
        else:
            raise SystemExit(f'부팅을 기다리다 시간이 초과됐습니다. 로그: {runtime / "emulator.log"}')
        print('JLPT 앱을 설치·실행합니다. 기존 학습 기록은 유지됩니다.', flush=True)
        call('-s', serial, 'install', '-r', str(apk))
        call('-s', serial, 'shell', 'am', 'start', '-n', 'kr.localstudy.jlpt_study/.MainActivity')
        print('에뮬레이터 창에서 사용할 수 있습니다.')


if __name__ == '__main__':
    try:
        main()
    except (subprocess.SubprocessError, OSError) as error:
        raise SystemExit(f'실행 오류: {error}') from error
