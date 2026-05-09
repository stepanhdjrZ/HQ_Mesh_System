import asyncio
import json
import os
from aiohttp import web, WSCloseCode

# Настройки
VERSION = "6.6"
IPA_NAME = "Messenger.ipa"
BUNDLE_ID = "com.hq.globalmesh"

async def handle_manifest(request):
    host = request.host
    manifest = f"""<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>items</key><array><dict><key>assets</key><array><dict>
    <key>kind</key><string>software-package</string><key>url</key><string>https://{host}/download/ipa</string>
    </dict></array><key>metadata</key><dict><key>bundle-identifier</key><string>{BUNDLE_ID}</string>
    <key>bundle-version</key><string>{VERSION}</string><key>kind</key><string>software</string>
    <key>title</key><string>HQ Global</string></dict></dict></array></dict></plist>"""
    return web.Response(text=manifest, content_type='text/xml')

async def handle_ipa(request):
    if os.path.exists(IPA_NAME):
        return web.FileResponse(IPA_NAME)
    return web.Response(text="IPA not found", status=404)

clients = set()

async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    clients.add(ws)
    
    # Сразу шлем проверку версии
    await ws.send_str(json.dumps({"type": "version_check", "version": VERSION}))
    
    try:
        async for msg in ws:
            if msg.type == web.WSMsgType.TEXT:
                data = json.loads(msg.data)
                # Рассылаем всем
                for client in clients:
                    await client.send_str(json.dumps({"type": "msg", "payload": [data]}))
    finally:
        clients.remove(ws)
    return ws

app = web.Application()
app.router.add_get('/manifest.plist', handle_manifest)
app.router.add_get('/download/ipa', handle_ipa)
app.router.add_get('/ws', websocket_handler)

if __name__ == "__main__":
    print(f"🚀 HQ Ultimate Server v{VERSION} запущен!")
    web.run_app(app, port=80)
