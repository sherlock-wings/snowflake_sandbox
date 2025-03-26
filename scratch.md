# 1. File Deleted but Not Staged/Committed (Still in Working Directory)

If you deleted the file (rm file.txt or via GUI) but haven't run git add or git commit yet, simply restore it from Git's index:

```bash
git restore file.txt
```

or (older Git versions):

```bash
git checkout -- file.txt
```

# 2. File Staged for Deletion (but Not Committed)

If you ran git add (staged the deletion) but haven’t committed:

```bash
git restore --staged file.txt  # Unstage deletion
git restore file.txt           # Restore file
```

# 3. File Deleted and Committed
If the deletion was already committed, you need to recover it from Git history.

## Option A: Find and Checkout the Last Commit That Had the File
1. Find the commit where the file existed:

```bash
git log --diff-filter=D -- file.txt
```
(Look for the last commit before deletion.)

2. Restore the file from that commit (<commit-hash>):

```bash
git checkout <commit-hash>^ -- file.txt
```
(The ^ means "the commit before deletion.")

## Option B: Use git revert (If Deletion Was Recent)
If you want to undo the entire commit that deleted the file:

```bash
git revert <commit-that-deleted-file> --no-edit
```

## Option C: Use git reflog (If You Lost the Commit)
If you can’t find the commit, check reflog for recent actions:

```bash
git reflog
```

Then restore from a pre-deletion state:

```bash
git checkout HEAD@{n} -- file.txt  # Replace `n` with the reflog entry
```

## 4. File Deleted in Multiple Commits (Deep Recovery)
If the file was deleted long ago, search all Git history:

```bash
git rev-list -n 1 HEAD -- file.txt  # Find last commit where file existed
git checkout <commit-hash> -- file.txt
```

## Key Notes:
- Git doesn’t truly "delete" files immediately—they linger in history until garbage collection (git gc).
- If you pushed the deletion, you’ll need to git push again after restoring the file.
- For permanently deleted files (after git gc), use file-recovery tools like photorec (but this is rare).