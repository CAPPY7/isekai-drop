# TCP proxy adding a fixed one-way delay in each direction (box stand-in for
# tc netem, which this kernel lacks). usage: delay_proxy.py listen_host listen_port target_host target_port delay_ms
import asyncio, sys, time
LH, LP, TH, TP, D = sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4]), float(sys.argv[5]) / 1000

async def pump(r, w):
    q = asyncio.Queue()
    held = [0]
    async def writer():
        while True:
            t, data = await q.get()
            if data is None:
                try: w.write_eof()
                except Exception: pass
                return
            dt = t + D - time.monotonic()
            if dt > 0: await asyncio.sleep(dt)
            w.write(data)
            held[0] -= len(data)
            await w.drain()
    task = asyncio.create_task(writer())
    try:
        while True:
            data = await r.read(256 * 1024)
            if not data: break
            q.put_nowait((time.monotonic(), data))
            held[0] += len(data)
            while held[0] > 16 * 1024 * 1024:
                await asyncio.sleep(0.001)
    except Exception:
        pass
    q.put_nowait((time.monotonic(), None))
    try: await task
    except Exception: pass

async def handle(cr, cw):
    sr, sw = await asyncio.open_connection(TH, TP)
    await asyncio.gather(pump(cr, sw), pump(sr, cw))
    for w in (cw, sw):
        try: w.close()
        except Exception: pass

async def main():
    s = await asyncio.start_server(handle, LH, LP)
    async with s: await s.serve_forever()
asyncio.run(main())
