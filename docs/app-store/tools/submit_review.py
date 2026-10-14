#!/usr/bin/env python3
"""Submits an app version (iOS) to App Review: submit_review.py APP_ID VERSION_ID.

Irreversible except by cancelling the submission in App Store Connect. Reuses an open (READY_FOR_REVIEW) submission,
so it is safe to run again after fixing a validation error. Needs the ASC_* variables of asc_api.py.
"""
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("asc_api", f"{HERE}/asc_api.py")
asc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(asc)

APP, VERSION = sys.argv[1], sys.argv[2]


def step(label, method, path, body=None):
    status, text = asc.call(method, path, body)
    print(f"[{status}] {label}")
    if status >= 300:
        print(text)
        sys.exit(1)
    return json.loads(text) if text else {}


open_ones = [s for s in step("list review submissions", "GET", f"/v1/apps/{APP}/reviewSubmissions")["data"]
             if s["attributes"]["state"] == "READY_FOR_REVIEW"]
if open_ones:
    submission = open_ones[0]["id"]
    print("reusing review submission", submission)
else:
    submission = step("create review submission", "POST", "/v1/reviewSubmissions", {
        "data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                 "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]["id"]

step("add version 1.0", "POST", "/v1/reviewSubmissionItems", {
    "data": {"type": "reviewSubmissionItems",
             "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission}},
                               "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION}}}}})

result = step("submit for review", "PATCH", f"/v1/reviewSubmissions/{submission}", {
    "data": {"type": "reviewSubmissions", "id": submission, "attributes": {"submitted": True}}})
print("submission", submission, "state:", result["data"]["attributes"]["state"])

version = step("read version state", "GET", f"/v1/appStoreVersions/{VERSION}")
print("version state:", version["data"]["attributes"]["appStoreState"])
