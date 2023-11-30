# Data Science Stack

Deploy MLflow, Jupyter Controller, Admission Webhook, and more using MicroK8s and Juju.

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [License](#license)

## Introduction

This repository contains a bash script that automates the deployment of MLflow, Jupyter Controller, Admission Webhook, and related charms using MicroK8s and Juju. The script sets up a user Kubernetes namespace, deploys pod defaults, and creates a user notebook, providing the IP for access.

## Prerequisites

Ensure you have the following dependencies installed before running the script:

- [Snap](https://snapcraft.io/)
- [MicroK8s](https://microk8s.io/)
- [Juju](https://juju.is/)
- [yq](https://github.com/mikefarah/yq)

## Installation

Clone the repository and run the script:

```bash
# Clone the repository
git clone https://github.com/misohu/data-science-stack-poc.git

# Navigate to the project directory
cd data-science-stack-poc

# Run the script
./deploy.sh
```

It takes about 8 minutes to deploy. At the end you will be prompted with URLs. For example:

```
Access the notebook at http://10.152.183.223/notebook/user-namespace/user-notebook/
Access MLflow ui at: http://10.152.183.34:5000
```