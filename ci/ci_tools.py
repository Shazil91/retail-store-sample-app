import sys
import json

def detect_changed_services(files):
    services = set()

    for f in files:
        if not f.startswith("src/"):
            continue

        parts = f.split("/")
        if len(parts) >= 2:
            services.add(parts[1])

    return {"service": sorted(list(services))}


def derive_image_tag(commit_sha):
    return commit_sha[:7]


def build_ecr_uri(account, region, service):
    return f"{account}.dkr.ecr.{region}.amazonaws.com/{service}"


def patch_helm_values(file_path, tag, repo):
    try:
        with open(file_path, "r") as f:
            content = f.read()

        content = content.replace("tag: latest", f"tag: {tag}")
        content = content.replace("repository: placeholder", f"repository: {repo}")

        with open(file_path, "w") as f:
            f.write(content)

    except FileNotFoundError:
        print(f"File not found: {file_path}")
        sys.exit(1)


def main():
    cmd = sys.argv[1]

    if cmd == "detect":
        files = sys.stdin.read().strip().splitlines()
        print(json.dumps(detect_changed_services(files)))

    elif cmd == "tag":
        print(derive_image_tag(sys.argv[2]))

    elif cmd == "ecr":
        print(build_ecr_uri(sys.argv[2], sys.argv[3], sys.argv[4]))

    elif cmd == "patch":
        patch_helm_values(sys.argv[2], sys.argv[3], sys.argv[4])

    else:
        print("Unknown command")
        sys.exit(1)


if __name__ == "__main__":
    main()
