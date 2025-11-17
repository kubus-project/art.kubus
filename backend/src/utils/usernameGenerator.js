// usernameGenerator.js
// Utility to generate usernames in the adjectivesubject_hash format

const adjectives = [
  'brave', 'calm', 'eager', 'fancy', 'gentle', 'happy', 'jolly', 'kind', 'lively', 'mighty',
  'nice', 'proud', 'quick', 'silly', 'tidy', 'witty', 'zealous', 'bold', 'clever', 'daring'
];

const subjects = [
  'lion', 'tiger', 'bear', 'eagle', 'shark', 'wolf', 'fox', 'owl', 'panda', 'otter',
  'falcon', 'whale', 'lynx', 'crane', 'bison', 'koala', 'gecko', 'mole', 'crow', 'deer'
];

function randomElement(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomHash(len = 4) {
  return Math.random().toString(36).substr(2, len);
}

function generateUsername() {
  const adjective = randomElement(adjectives);
  const subject = randomElement(subjects);
  const hash = randomHash(4);
  return `${adjective}${subject}_${hash}`;
}

module.exports = { generateUsername };