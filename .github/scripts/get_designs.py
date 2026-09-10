import argparse
import json
from pathlib import Path
import sys


def parse_lvs_config(file_path):
    """Parses the LVS config file at the specified path."""
    with open(file_path) as f:
        data = json.load(f)
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--design", required=True, help="The path to the design.")
    args = parser.parse_args()

    design = Path(args.design)
    config_file = design / "lvs" / "openframe_project_wrapper" / "lvs_config.json"
    data = parse_lvs_config(config_file)
    f = open("harden_sequence.txt", "w")
    for d in data["LVS_VERILOG_FILES"]:
        macro_name = Path(d).name.removesuffix(".v")
        if macro_name.startswith('$'):
            macro_name = data[macro_name[1:]]
        openlane_config = design / "openlane" / macro_name / "config.json"
        if not openlane_config.is_file(): # skip macros that don't have a config.json
            continue
        f.write(f"{macro_name} ")
    f.close()


if __name__ == "__main__":
    main()
