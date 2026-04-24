import sys
import json
import hashlib

def detect_changed_services(files):
    services = set()

    for f in files:
        if "src/cart" in f:
            services.add("cart")
        elif "src/catalog" in f:
            services.add("catalog")
        elif "src/orders" in f:
            services.add("orders")

    return {"service": sorted(list(services))}

def derive_image_tag(commit_sha):
    return commit_sha[:7]

def build_ecr_uri(account, region, service):
    return f"{account}.dkr.ecr.{region}.amazonaws.com/{service}"

def patch_helm_values(file_path, tag, repo):
    with open(file_path, "r") as f:
        content = f.read()

    content = content.replace("tag: latest", f"tag: {tag}")
    content = content.replace("repository: placeholder", f"repository: {repo}")

    with open(file_path, "w") as f:
        f.write(content)

def main():
    cmd = sys.argv[1]

    if cmd == "detect":
        files = sys.stdin.read().strip().split("\n")
        print(json.dumps(detect_changed_services(files)))

    elif cmd == "tag":
        print(derive_image_tag(sys.argv[2]))

    elif cmd == "ecr":
        print(build_ecr_uri(sys.argv[2], sys.argv[3], sys.argv[4]))

    else:
        print("Unknown command")
        sys.exit(1)

if __name__ == "__main__":
    main()
