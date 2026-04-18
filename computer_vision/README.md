# Computer Vision

This folder contains the occupancy-detection code, checkpoints, test assets, and training utilities used by the backend occupancy pipeline.

If you are only working on booking, auth, or the library UI, you do not need this module to run locally.

## What Is Actually Used

For normal backend execution, the important pieces are:

- [`core/seat_occupancy_detector.py`](./core/seat_occupancy_detector.py)
- model checkpoints referenced by `CV_OCCUPANCY_MODEL_PATH` and `CV_SEAT_MODEL_PATH`
- optional sample data under [`test/data`](./test/data)

The backend reads those paths from `backend/.env`. The default local template points to files under [`model/`](./model/).

## Quick Smoke Test

From a Python environment with `torch`, `torchvision`, `opencv-python`, `ultralytics`, and `python-dotenv` installed:

```bash
cd computer_vision/test
python test.py
```

The script will read images and videos from [`test/data`](./test/data) and write annotated outputs into the result folders in [`test/`](./test/).

## Folder Guide

- [`core/`](./core/): runtime detection logic
- [`model/`](./model/): current model checkpoints used by local defaults
- [`Models/`](./Models/): older or alternate checkpoint layout kept in the repo
- [`test/`](./test/): manual test runner plus sample inputs and outputs
- [`train_models/`](./train_models/): training and dataset-prep scripts

## External Assets

Model and dataset links that were previously scattered across several small README files are collected here:

- models: <https://drive.google.com/drive/folders/1OHSU8zHXdzQPPLG9O6gvppZxmx9BvDEn?usp=sharing>
- datasets: <https://drive.google.com/drive/folders/12xXw4GAQ3IsIupT-8eQ8PumnqNqRLHhF?usp=sharing>
- extra test data: <https://drive.google.com/drive/folders/18y3XBVPd7V8krpw8GH911NnN9-yK3Gw8?usp=sharing>
- extra test data mirror: <https://connecthkuhk-my.sharepoint.com/:f:/g/personal/haoqc_connect_hku_hk/IgCw4Xf8XwJ8Q7AzdDmNfGWUAU67R0UgnWCeRYdFW7heE-4?e=zcyjmL>

## Notes

- This directory is a mix of runtime code and experiment history. Keep backend-facing changes focused on `core/`, model paths, and test coverage.
- If your backend occupancy endpoints are disabled, you can ignore this module entirely during local app development.
