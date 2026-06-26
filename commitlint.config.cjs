module.exports = {
  extends: ['@commitlint/config-conventional'],

  rules: {
    'body-max-line-length': [1, 'always', 100],
    'subject-case': [1, 'always', ['lower-case', 'sentence-case']],
    'signed-off-by': [2, 'always', 'Signed-off-by'],
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
  `
};
