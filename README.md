# OpenHamClock Dockerized

A multi-architecture Docker implementation of [OpenHamClock](https://github.com/accius/openhamclock). This repository provides a streamlined way to run OpenHamClock in a containerized environment, supporting both **AMD64** and **ARM64** architectures.

---

## ✨ Features

- **Multi-Arch Support:** Optimized for both x86_64 and ARM64 (Raspberry Pi, Orange Pi, etc.).
- **Lightweight:** Built on Alpine Linux to minimize image size and resource overhead.
- **Dynamic Resolution:** Leverages the unified web interface on port 8081.
- **Rootless Support:** Designed to run with custom UID/GID for better security and file permission management.

---

## 🚀 Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Installation

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/your-username/openhamclock-docker.git](https://github.com/your-username/openhamclock-docker.git)
   cd openhamclock-docker
