const CHERRY_PICK_REGEX =
  /^\(cherry picked from commit [0-9a-f]{7,40}\)$/;

const SIGNED_OFF_REGEX =
  /^Signed-off-by:\s.+\s<[^<>]+>$/;


module.exports = {
  extends: ['@commitlint/config-conventional'],

  rules: {
    'body-max-line-length': [1, 'always', 100],
    'subject-case': [1, 'always', ['lower-case', 'sentence-case']],
    'signed-off-anywhere': [2, 'always'],
    'cherry-pick-at-end': [2, 'always'],
    'body-leading-blank': [2, 'always'], // body must be preceded by a blank line
                                         // exit with error if not
  },

  helpUrl: `
  Commit messages must follow conventional commit format:
  https://www.conventionalcommits.org/en/v1.0.0/#summary
      type(optional-scope): subject

      [optional body]
  * To bypass pre-commit hooks run 'git commit --no-verify'
  >>> Use "npm run commit" for interactive prompt. <<<
  `,

  plugins: [
    {
      rules: {
        'signed-off-anywhere': (parsed) => {
          const { raw } = parsed;

          if (!raw) {
            return [true];
          }

          const lines = raw.trim().split('\n');
          const foundIndex = lines.findIndex(line =>
            SIGNED_OFF_REGEX.test(line.trim())
          );

          // If signed off is missing - fail
          if (foundIndex === -1) {
            return [
              false,
              'Signed-off-by: is missing in the commit message',
            ];
          }

          return [true];
        },
        'cherry-pick-at-end': (parsed) => {
          const { raw } = parsed;

          if (!raw) {
            return [true];
          }

          const lines = raw.trim().split('\n');
          const foundIndex = lines.findIndex(line =>
            CHERRY_PICK_REGEX.test(line.trim())
          );

          // If cherry pick is missing - pass
          if (foundIndex === -1) {
            return [true];
          }

          // Cherry pick line must be at the end as a consequence
          // of "git cherry-pick -x"
          if (foundIndex !== lines.length - 1) {
            return [
              false,
              'Cherry-pick line must be the last one in the commit message',
            ];
          }

          return [true];
        },
      },
    },
  ],
};
