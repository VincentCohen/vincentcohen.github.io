const output = document.querySelector('#output');
const input = document.querySelector('#command');
const themeButton = document.querySelector('#theme');
const history = [];
let historyIndex = 0;
const fortunes = [
  'Make something small. Make it yours.',
  'There is no cloud. Just someone else’s computer.',
  'The best time to save your work was five minutes ago.',
  'Have you tried going for a walk and coming back?',
  'A personal website is a room on the internet. Put up a poster.'
];
function print(message) {
  const line = document.createElement('p');
  line.textContent = message;
  output.append(line);
  while (output.children.length > 60) output.firstElementChild.remove();
  output.scrollTop = output.scrollHeight;
}
function theme(value) {
  const green = value ? value === 'green' : !document.body.classList.contains('green');
  document.body.classList.toggle('green', green);
  themeButton.textContent = green ? '[ GREEN ]' : '[ AMBER ]';
  themeButton.setAttribute('aria-label', `Switch to ${green ? 'amber' : 'green'} phosphor`);
  try { localStorage.setItem('vc-theme', green ? 'green' : 'amber'); } catch {}
}
function run(raw) {
  const command = raw.trim().toLowerCase();
  if (!command) return;
  history.push(raw.trim());
  historyIndex = history.length;
  print(`guest@vc:~$ ${raw.trim()}`);
  switch (command) {
    case 'help': print('AVAILABLE COMMANDS\nabout      Meet the operator\ngithub     Show my GitHub address\nlinkedin   Connect on LinkedIn\nwork       Explore my background\nfortune    A small piece of wisdom\ntheme      Switch amber / green phosphor\ndate       The time in Amsterdam\nclear      A fresh start\nsecret     You didn’t see this one\n\nTip: ↑ / ↓ recalls your commands. Tab completes them.'); break;
    case 'about': print('Vincent Cohen — Amsterdam.\nProduct-focused software development, backend engineering, and team leadership.\nType work for my background or linkedin to connect.'); break;
    case 'work': print('Lightspeed — backend development and team leadership.\nSEOshop v2 (2015) — modular SaaS, API-based business logic, and faster storefronts.\nGrafisch Lyceum Amsterdam — 2007–2011.\nLanguages — Dutch and English.'); break;
    case 'linkedin':
    case 'github': {
      const line = document.createElement('p');
      const link = document.createElement('a');
      link.href = command === 'linkedin' ? 'https://www.linkedin.com/in/vecohen/' : 'https://github.com/VincentCohen';
      link.textContent = command === 'linkedin' ? '↗ linkedin.com/in/vecohen' : '↗ github.com/VincentCohen';
      link.target = '_blank'; link.rel = 'noopener noreferrer';
      line.append(link); output.append(line); output.scrollTop = output.scrollHeight; break;
    }
    case 'fortune': print(fortunes[Math.floor(Math.random() * fortunes.length)]); break;
    case 'theme': theme(); print('Phosphor switched. Your eyes, your rules.'); break;
    case 'date': print(new Date().toLocaleString('en-GB', { timeZone: 'Europe/Amsterdam', dateStyle: 'full', timeStyle: 'long' })); break;
    case 'clear': output.replaceChildren(); break;
    case 'secret': print('     /\_/\\\n    ( o.o )  You found the resident terminal cat.\n     > ^ <   It has root access.'); break;
    case 'sudo': case 'sudo rm -rf /': print('Nice try. The cat is the only administrator here.'); break;
    case 'ls': print('hello.txt   background.log   linkedin.url   github.url   definitely-not-a-cat.exe'); break;
    case 'hello': case 'hi': print('Hey there. Glad you dropped by.'); break;
    default: print(`Command not found: ${command}\nTry “help” — no terminal experience required.`);
  }
  input.value = '';
}
document.querySelector('#command-form').addEventListener('submit', event => { event.preventDefault(); run(input.value); });
document.querySelectorAll('[data-command]').forEach(button => button.addEventListener('click', () => {
  run(button.dataset.command);
  document.querySelector('.console').scrollIntoView({ block: 'nearest' });
}));
themeButton.addEventListener('click', () => theme());
input.addEventListener('keydown', event => {
  if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
    event.preventDefault();
    historyIndex = Math.max(0, Math.min(history.length, historyIndex + (event.key === 'ArrowUp' ? -1 : 1)));
    input.value = history[historyIndex] || '';
  }
  if (event.key === 'Tab' && input.value.trim()) {
    const matches = ['help', 'about', 'github', 'linkedin', 'work', 'fortune', 'theme', 'date', 'clear', 'secret'].filter(command => command.startsWith(input.value.trim().toLowerCase()));
    if (matches.length === 1) { event.preventDefault(); input.value = matches[0]; }
  }
});
function updateClock() {
  document.querySelector('#clock').textContent = 'AMSTERDAM · ' + new Date().toLocaleTimeString('en-GB', { timeZone: 'Europe/Amsterdam' });
}
try { if (localStorage.getItem('vc-theme') === 'green') theme('green'); } catch {}
document.querySelector('#year').textContent = new Date().getFullYear();
updateClock();
setInterval(updateClock, 1000);
