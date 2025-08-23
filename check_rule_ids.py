import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
import sys
import os
from collections import defaultdict, Counter

def run_git_command(args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ Git command failed: {' '.join(args)}")
        print(f"Error: {e.stderr}")
        raise

def get_target_branch():
    """Détermine la branche cible selon l'environnement"""
    # GitLab CI variables
    if os.getenv('CI_MERGE_REQUEST_TARGET_BRANCH_NAME'):
        return f"origin/{os.getenv('CI_MERGE_REQUEST_TARGET_BRANCH_NAME')}"
    elif os.getenv('CI_DEFAULT_BRANCH'):
        return f"origin/{os.getenv('CI_DEFAULT_BRANCH')}"
    # Fallback pour GitHub ou local
    else:
        return "origin/main"

def setup_git_environment():
    """Configure Git pour GitLab CI"""
    if os.getenv('CI'):  # En environnement CI
        try:
            # Fetch toutes les branches
            run_git_command(["git", "fetch", "origin"])
            # Configure Git si nécessaire
            run_git_command(["git", "config", "--global", "user.email", "ci@gitlab.com"])
            run_git_command(["git", "config", "--global", "user.name", "GitLab CI"])
        except subprocess.CalledProcessError as e:
            print(f"⚠️ Warning during git setup: {e}")

def get_changed_rule_files():
    target_branch = get_target_branch()
    print(f"🔍 Comparing against: {target_branch}")
    
    try:
        # Dans GitLab CI, on peut avoir besoin de faire un fetch d'abord
        if os.getenv('CI'):
            run_git_command(["git", "fetch", "origin"])
        
        # Essayer différentes approches selon l'environnement
        commands_to_try = [
            ["git", "diff", "--name-status", f"{target_branch}...HEAD"],
            ["git", "diff", "--name-status", f"{target_branch}..HEAD"],
            ["git", "diff", "--name-status", target_branch],
            ["git", "diff", "--name-status", "HEAD~1"],
            ["git", "diff", "--name-status", "--cached"],
            ["git", "ls-files", "--others", "--exclude-standard"]  # fichiers non trackés
        ]
        
        output = ""
        for cmd in commands_to_try:
            try:
                print(f"🔄 Trying: {' '.join(cmd)}")
                output = run_git_command(cmd)
                if output.strip():
                    print(f"✅ Command succeeded with output")
                    break
                else:
                    print(f"⚠️ Command succeeded but no output")
            except subprocess.CalledProcessError as e:
                print(f"❌ Command failed: {e}")
                continue
        
        # Si aucune commande ne donne de résultat, lister tous les fichiers XML
        if not output.strip():
            print("🔄 No changes detected via git diff, checking all XML files in rules/")
            rules_dir = Path("rules")
            if rules_dir.exists():
                xml_files = list(rules_dir.glob("*.xml"))
                changed_files = [("+", f) for f in xml_files]  # Traiter comme nouveaux fichiers
                print(f"📁 Found XML files: {[f.name for f in xml_files]}")
                return changed_files
        
        changed_files = []
        for line in output.strip().splitlines():
            if not line.strip():
                continue
            parts = line.strip().split(maxsplit=1)
            if len(parts) == 1:  # Fichier non tracké (git ls-files)
                file_path = parts[0]
                status = "A"
            elif len(parts) == 2:
                status, file_path = parts
            else:
                continue
                
            print(f"📄 Processing: {status} {file_path}")
            if file_path.startswith("rules/") and file_path.endswith(".xml"):
                changed_files.append((status, Path(file_path)))
        
        print(f"📋 Final changed files: {[(s, f.name) for s, f in changed_files]}")
        return changed_files
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to get changed files: {e}")
        sys.exit(1)

def extract_rule_ids_from_xml(content):
    ids = []
    try:
        # Nettoyer le contenu avant parsing
        content = content.strip()
        if not content:
            return ids
            
        # Wrap multiple root elements in a fake <root> tag to avoid parse errors
        wrapped = f"<root>{content}</root>"
        root = ET.fromstring(wrapped)
        for rule in root.findall(".//rule"):
            rule_id = rule.get("id")
            if rule_id and rule_id.isdigit():
                ids.append(int(rule_id))
    except ET.ParseError as e:
        print(f"⚠️ XML Parse Error: {e}")
    return ids

def get_rule_ids_per_file_in_target():
    target_branch = get_target_branch()
    
    try:
        # Assurer que la branche cible est disponible
        run_git_command(["git", "fetch", "origin"])
        files_output = run_git_command(["git", "ls-tree", "-r", target_branch, "--name-only"])
    except subprocess.CalledProcessError:
        print(f"⚠️ Cannot access {target_branch}, using current HEAD")
        files_output = run_git_command(["git", "ls-tree", "-r", "HEAD", "--name-only"])
    
    xml_files = [f for f in files_output.splitlines() if f.startswith("rules/") and f.endswith(".xml")]

    rule_id_to_files = defaultdict(set)
    for file in xml_files:
        try:
            content = run_git_command(["git", "show", f"{target_branch}:{file}"])
            rule_ids = extract_rule_ids_from_xml(content)
            for rule_id in rule_ids:
                rule_id_to_files[rule_id].add(file)
        except subprocess.CalledProcessError:
            # Si le fichier n'existe pas dans la branche cible, ignorer
            continue
    return rule_id_to_files

def get_rule_ids_from_target_version(file_path: Path):
    target_branch = get_target_branch()
    try:
        content = run_git_command(["git", "show", f"{target_branch}:{file_path.as_posix()}"])
        return extract_rule_ids_from_xml(content)
    except subprocess.CalledProcessError:
        return []

def detect_duplicates(rule_ids):
    counter = Counter(rule_ids)
    return [rule_id for rule_id, count in counter.items() if count > 1]

def print_conflicts(conflicting_ids, rule_id_to_files):
    print("❌ Conflicts detected:")
    for rule_id in sorted(conflicting_ids):
        files = rule_id_to_files.get(rule_id, [])
        print(f"  - Rule ID {rule_id} found in:")
        for f in files:
            print(f"    • {f}")

def main():
    print("🚀 Starting rule ID conflict checker...")
    print(f"Environment: {'GitLab CI' if os.getenv('CI') else 'Local'}")
    
    # Debug info
    print("🐛 Debug info:")
    print(f"CI: {os.getenv('CI')}")
    print(f"CI_MERGE_REQUEST_TARGET_BRANCH_NAME: {os.getenv('CI_MERGE_REQUEST_TARGET_BRANCH_NAME')}")
    print(f"CI_DEFAULT_BRANCH: {os.getenv('CI_DEFAULT_BRANCH')}")
    print(f"CI_COMMIT_REF_NAME: {os.getenv('CI_COMMIT_REF_NAME')}")
    print(f"CI_COMMIT_SHA: {os.getenv('CI_COMMIT_SHA')}")
    print(f"Working directory: {os.getcwd()}")
    
    # Liste tous les fichiers XML dans rules/
    rules_dir = Path("rules")
    if rules_dir.exists():
        xml_files = list(rules_dir.glob("*.xml"))
        print(f"📁 XML files in rules/: {[f.name for f in xml_files]}")
    else:
        print("❌ rules/ directory not found!")
    
    # Configuration de l'environnement Git
    setup_git_environment()
    
    # Debug git status
    try:
        git_status = run_git_command(["git", "status", "--porcelain"])
        print(f"📋 Git status: {git_status.strip() if git_status.strip() else 'clean'}")
        
        # Branches disponibles
        branches = run_git_command(["git", "branch", "-a"])
        print(f"🌿 Available branches: {branches.strip()}")
        
        # Dernier commit
        last_commit = run_git_command(["git", "log", "--oneline", "-1"])
        print(f"📝 Last commit: {last_commit.strip()}")
    except subprocess.CalledProcessError as e:
        print(f"⚠️ Debug git command failed: {e}")
    
    changed_files = get_changed_rule_files()
    if not changed_files:
        print("⚠️ No rule files detected as changed via git diff.")
        # En dernier recours, vérifier tous les fichiers XML s'il y a un argument --force
        if "--force" in sys.argv or os.getenv('FORCE_CHECK_ALL_RULES'):
            print("🔄 Force checking all XML files in rules/")
            rules_dir = Path("rules")
            if rules_dir.exists():
                xml_files = list(rules_dir.glob("*.xml"))
                changed_files = [("A", f) for f in xml_files]  # Traiter comme nouveaux
                print(f"📁 Force checking: {[f.name for f in xml_files]}")
            
        if not changed_files:
            print("✅ No rule files to check.")
            return

    rule_id_to_files_target = get_rule_ids_per_file_in_target()

    print(f"🔍 Checking rule ID conflicts for files: {[f.name for _, f in changed_files]}")

    for status, path in changed_files:
        print(f"\n🔎 Checking file: {path.name}")

        try:
            if path.exists():
                dev_content = path.read_text(encoding='utf-8')
            else:
                print(f"⚠️ File {path.name} does not exist locally, skipping...")
                continue
                
            dev_ids = extract_rule_ids_from_xml(dev_content)
        except Exception as e:
            print(f"⚠️ Could not read {path.name}: {e}")
            continue

        # Check for internal duplicates
        duplicates = detect_duplicates(dev_ids)
        if duplicates:
            print(f"❌ Duplicate rule IDs detected in {path.name}: {sorted(duplicates)}")
            sys.exit(1)

        if status == "A":
            # New file
            conflicting_ids = set(dev_ids) & set(rule_id_to_files_target.keys())
            if conflicting_ids:
                print_conflicts(conflicting_ids, rule_id_to_files_target)
                sys.exit(1)
            else:
                print(f"✅ No conflict in new file {path.name}")

        elif status == "M":
            # Modified file
            target_ids = get_rule_ids_from_target_version(path)
            if set(dev_ids) == set(target_ids):
                print(f"ℹ️ {path.name} modified but rule IDs unchanged.")
                continue

            new_or_changed_ids = set(dev_ids) - set(target_ids)
            conflicting_ids = new_or_changed_ids & set(rule_id_to_files_target.keys())

            if conflicting_ids:
                print_conflicts(conflicting_ids, rule_id_to_files_target)
                sys.exit(1)
            else:
                print(f"✅ Modified file {path.name} has no conflicting rule IDs.")

    print("\n✅ All rule file changes passed conflict checks.")

if __name__ == "__main__":
    main()
