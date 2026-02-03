# GitHub Setup Instructions

## Prerequisites
- Git installed on your machine
- GitHub account
- GitHub CLI or SSH key set up

## Setup Steps

### 1. Create Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `waze-alerts-monitor`
3. Description: `Real-time Waze alert notifications with voice alerts and customizable filtering`
4. Choose **Public** to share with others
5. Add `.gitignore`: **Flutter**
6. Add license: **MIT License**
7. Click **Create repository**

### 2. Add Remote and Push

Replace `<YOUR_USERNAME>` with your actual GitHub username:

```bash
cd "C:\Users\michael.guber\Desktop\Waze Notification\waze_alerts_new"

# Add GitHub remote
git remote add origin https://github.com/<YOUR_USERNAME>/waze-alerts-monitor.git

# Rename branch to main (GitHub convention)
git branch -M main

# Push to GitHub
git push -u origin main
```

### 3. Using SSH (Optional, Recommended)

For passwordless authentication:

```bash
# Check if you have SSH keys
cat ~/.ssh/id_rsa.pub

# If not, create one
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Add to GitHub Settings > SSH and GPG keys > New SSH key
# Then use SSH URL instead:
git remote set-url origin git@github.com:<YOUR_USERNAME>/waze-alerts-monitor.git
```

### 4. Using GitHub CLI (Optional, Easiest)

If you have GitHub CLI installed:

```bash
gh auth login  # Follow prompts to authenticate

cd "C:\Users\michael.guber\Desktop\Waze Notification\waze_alerts_new"

# Create repo and push in one command
gh repo create waze-alerts-monitor --public --source=. --remote=origin --push
```

## After Pushing

1. **Verify on GitHub**
   - Go to https://github.com/<YOUR_USERNAME>/waze-alerts-monitor
   - Check that all files are there
   - README should display nicely

2. **Add Topics** (GitHub → Settings → Topic)
   - `flutter`
   - `waze`
   - `alerts`
   - `gps`
   - `android`
   - `notifications`

3. **Add Description**
   - Real-time Waze alert notifications with voice alerts, GPS tracking, and customizable filtering

4. **Enable Features** (GitHub → Settings)
   - Issues: ✓
   - Discussions: ✓
   - Projects: Optional
   - Wiki: Optional

## Future Updates

To push updates after making changes:

```bash
cd "C:\Users\michael.guber\Desktop\Waze Notification\waze_alerts_new"

# Check what changed
git status

# Stage all changes
git add .

# Commit with descriptive message
git commit -m "Add new feature: X"

# Push to GitHub
git push origin main
```

## Common Commands

```bash
# View remote
git remote -v

# View current branch
git branch

# View commit history
git log --oneline

# View changes
git diff

# Undo last commit (keep changes)
git reset --soft HEAD~1

# View branches on GitHub
git branch -r
```

## Troubleshooting

### Authentication Failed
```bash
# For HTTPS, update credentials
git remote set-url origin https://<TOKEN>@github.com/<USERNAME>/waze-alerts-monitor.git

# Or use SSH
git remote set-url origin git@github.com:<USERNAME>/waze-alerts-monitor.git
```

### Push Rejected
```bash
# Pull latest changes first
git pull origin main

# Then push
git push origin main
```

### Need to Add Files to Last Commit
```bash
git add .
git commit --amend --no-edit
git push -f origin main
```

## Repository Structure

Your GitHub repo will contain:

```
waze-alerts-monitor/
├── lib/                          # Dart source code
├── android/                       # Android-specific code
├── ios/                          # iOS configuration
├── pubspec.yaml                  # Project dependencies
├── README.md                      # Project documentation
├── LICENSE                       # MIT License
├── .gitignore                    # Git ignore rules
├── analysis_options.yaml         # Dart linter config
└── assets/                       # App resources
    └── icon.svg                  # App icon
```

## Next Steps

1. Share the GitHub link: `https://github.com/<YOUR_USERNAME>/waze-alerts-monitor`
2. Add build badge to README (optional)
3. Set up GitHub Actions for CI/CD (optional)
4. Accept pull requests and issues from community

---

Need help? Check the README.md for more information!
