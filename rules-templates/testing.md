---
globs: ["*test*", "*spec*", "tests/**", "test/**"]
---
- Test names: test_<thing>_<condition>_<expected>
- pytest only — no unittest
- Minimize mocking; prefer real dependencies when feasible
- Edge cases required
- One test = one behavior verification
- Arrange-Act-Assert pattern
