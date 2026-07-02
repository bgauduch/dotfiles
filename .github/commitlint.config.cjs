// Conventional Commits enforcement (CI only — no local node dependency).
// Body/footer line-length rules are disabled so wrapped bodies and the
// trailer URLs don't fail lint.
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'body-max-line-length': [0, 'always'],
    'footer-max-line-length': [0, 'always'],
  },
};
