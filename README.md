# Optimized QBCore Chat Resource

A high-performance refactor of the standard Cfx.re chat resource, specifically tailored for QBCore frameworks. This version eliminates the common "idle drain" associated with chat scripts, bringing resource monitor (resmon) usage down from **0.03ms** to a solid **0.00ms**.

## 🚀 Performance Comparison

| State | Original Chat | Optimized Chat |
| :--- | :--- | :--- |
| **Idle (Resmon)** | 0.03ms - 0.05ms | **0.00ms** |
| **Active (Typing)** | 0.05ms+ | 0.01ms |
| **Input Handling** | Per-frame Lua Loop | Native Engine Binding |

## 🛠 Key Improvements

### 1. Zero-Loop Input Detection
Standard chat resources use a `Citizen.CreateThread` with a `while true` loop to check if the "T" key is pressed every single frame. 
- **The Fix:** We removed the loop entirely and implemented `RegisterKeyMapping`. This offloads the key listener to the GTA V engine's native code. The Lua script only wakes up when the key is actually pressed.

### 2. Intelligent Thread Hibernation
The logic handling NUI focus now uses dynamic wait times. 
- When the chat is closed, the thread sleeps for longer intervals.
- When the chat is activating, it checks with precision only during the transition state.

### 3. Modern Lua Support
Utilizes `lua54 'yes'` for more efficient memory management and garbage collection, ensuring the resource stays lean even after hours of server uptime.

## 📥 Installation

1. **Path:** Place the `chat` folder into your `[system]` or `[resources]` directory.
2. **Standard Setup:** Ensure you have `ensure chat` in your `server.cfg`.
3. **Compatibility:** This resource is 100% compatible with existing QBCore commands (`/me`, `/do`, `/ooc`, etc.) and standard chat themes.

## ⌨️ Controls
- **Default Key:** `T`
- **Customization:** Because this uses native key mapping, players can now rebind their chat key in:
  `Settings -> Key Bindings -> FiveM -> Open Chat`

## 📝 Technical Overview (cl_chat.lua)
The core of the optimization lies in replacing the expensive loop with:
```lua
RegisterCommand('chat_open', function()
    if not chatInputActive then
        chatInputActive = true
        SendNUIMessage({ type = 'ON_OPEN' })
    end
end, false)

RegisterKeyMapping('chat_open', 'Open Chat', 'keyboard', 'T')
```

## 🤝 Credits
Base Logic: Cfx.re
Optimization: Refactored for TMGCore performance standards.

P.S: Currently working on creating a full QBCore Remake at the moment, so if that interests you, follow my social media. 
Twitch: TMG_Manic
YouTube: TMG_Manic
