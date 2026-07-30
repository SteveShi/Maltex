# Open Source Acknowledgements & Licenses / 开源致谢与许可声明

Maltex is built with open source software. Below is a list of open source components and projects used in Maltex, along with their respective license information.

Maltex 基于开源软件构建。以下是 Maltex 使用的开源组件与项目及其许可证信息。

---

## Maltex

- **License / 协议**: [MIT License](./LICENSE)
- **Copyright / 版权**: Copyright (c) Steve Shi

---

## Bundled Engines / 嵌入式引擎组件

### aria2

Maltex bundles `aria2c` as an external executable process and communicates with it via standard JSON-RPC interface.

Maltex 以独立外部可执行文件形式打包 `aria2c`，并通过标准 JSON-RPC 接口与其进行进程间通信。

- **Project / 项目**: [aria2](https://github.com/aria2/aria2)
- **License / 协议**: [GNU General Public License v2.0 (GPLv2)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
- **Source Code / 源码**: [https://github.com/aria2/aria2](https://github.com/aria2/aria2)

### aria2-next (Experimental Engine / 实验性内核)

- **Project / 项目**: [aria2-next](https://github.com/AnInsomniacy/aria2-next)
- **License / 协议**: [GNU General Public License v2.0 (GPLv2)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
- **Source Code / 源码**: [https://github.com/AnInsomniacy/aria2-next](https://github.com/AnInsomniacy/aria2-next)

---

## Dependencies & Swift Packages / 依赖组件

### Sparkle

Software update framework for macOS.

- **Project / 项目**: [Sparkle](https://github.com/sparkle-project/Sparkle)
- **License / 协议**: MIT License

### Aria2Kit

Swift wrapper for aria2 JSON-RPC protocol.

- **Project / 项目**: [Aria2Kit](https://github.com/matsuba/Aria2Kit)
- **License / 协议**: MIT License

### Alamofire

Elegant HTTP Networking in Swift.

- **Project / 项目**: [Alamofire](https://github.com/Alamofire/Alamofire)
- **License / 协议**: MIT License
