/** @type {import('@commitlint/types').UserConfig} */
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'body-max-line-length': [1, 'always', 200],
    'type-enum': [
      1,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'test',
        'chore',
        'build',
        'ci',
        'revert',
        'wip',
        'update',
        'add',
        'remove',
        'web',
        'copilot',
      ],
    ],
    'subject-case': [0],
    'type-case': [0],
    'subject-max-length': [1, 'always', 150],
    'header-max-length': [1, 'always', 170],
  },
  ignores: [
    // Ignore commits with Copilot as co-author (user + Copilot collaboration)
    (commit) => commit.includes('Co-authored-by: Copilot'),
    // Ignore commits from Copilot coding agent (Copilot as main author, user as co-author)
    (commit) =>
      !commit.includes('Co-authored-by: Copilot') &&
      commit.includes('Co-authored-by:'),
    // Ignore Copilot coding agent's initial plan commits
    (commit) => /^Initial plan\s*$/.test(commit.trim()),
    // Ignore merge commits
    (commit) => /^Merge\s/.test(commit),
    // Ignore revert commits (GitHub UI creates these)
    (commit) => /^Revert\s/.test(commit),
    // Ignore Dependabot commits
    (commit) => /^Bump\s.+\sfrom\s.+\sto\s/.test(commit),
    // Ignore GitHub web editor commits
    (commit) => /^(Create|Update|Delete|Rename)\s/.test(commit),
    // Ignore signed-off commits
    (commit) => commit.includes('Signed-off-by:'),
    // Ignore release commits
    (commit) => /^(\[Release\]|Release)\s*v?\d+/.test(commit),
  ],
};
