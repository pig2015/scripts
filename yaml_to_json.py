#!/bin/env python3


import sys
import yaml
import json


def convert(yaml_file_path):
    with open(yaml_file_path, 'r') as f:
        yaml_obj = yaml.safe_load(f)
    json_str = json.dumps(yaml_obj)
    print(json_str)
    json_dict = json.loads(json_str)
    json_file_path = yaml_file_path
    if json_file_path.endswith('.yaml'):
        json_file_path = json_file_path[:-5]
    json_file_path += '.json'
    with open(json_file_path, 'w') as f:
        f.write(json_str)


for file_path in sys.argv[1:]:
    convert(file_path)

