// A bounded illustration of the loading contract; it does not execute peers.
const model = document.querySelector('#composition');
const order = model.querySelector('#composition-order');
const configured = model.querySelector('#composition-configured');
const permutations = [
  ['A', 'B', 'C'], ['A', 'C', 'B'], ['B', 'A', 'C'],
  ['B', 'C', 'A'], ['C', 'A', 'B'], ['C', 'B', 'A'],
];
let orderIndex = 0;
let repeatA = false;

function render() {
  const sequence = [...permutations[orderIndex]];
  if (repeatA) sequence.push('A');
  order.textContent = sequence.join(' → ');
  configured.textContent = [...new Set(sequence)].sort().join(' · ');
}

model.querySelector('#composition-reorder').addEventListener('click', () => {
  orderIndex = (orderIndex + 1) % permutations.length;
  repeatA = false;
  render();
});
model.querySelector('#composition-reload').addEventListener('click', () => {
  repeatA = true;
  render();
});
model.querySelector('.composition-controls').hidden = false;
