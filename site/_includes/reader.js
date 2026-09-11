/* Pair-programmed by SE Community + Cortex Code */
document.addEventListener('DOMContentLoaded', () => {
  const input = document.getElementById('reader-query');
  const results = document.getElementById('reader-results');
  const search = input.closest('.reader-search');
  const entries = JSON.parse(document.getElementById('reader-index').textContent);
  function showResults() {
    results.replaceChildren();
    const terms = input.value.toLowerCase().trim().split(/\s+/).filter(Boolean);
    results.hidden = terms.length === 0;
    if (!terms.length) return;
    const matches = entries.filter(entry => terms.every(term => `${entry.title} ${entry.text}`.toLowerCase().includes(term)))
      .sort((left, right) => terms.filter(term => right.title.toLowerCase().includes(term)).length - terms.filter(term => left.title.toLowerCase().includes(term)).length);
    const status = document.createElement('p');
    status.textContent = matches.length ? `${matches.length > 12 ? 'Showing 12 of ' : ''}${matches.length} results` : 'No matches. Try a broader topic or browse the catalog.';
    results.append(status);
    for (const entry of matches.slice(0, 12)) {
      const link = document.createElement('a');
      link.href = entry.url;
      link.textContent = entry.title;
      const scope = document.createElement('small');
      scope.textContent = entry.scope;
      link.append(scope);
      results.append(link);
    }
  }
  input.addEventListener('input', showResults);
  input.addEventListener('focus', showResults);
  search.addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); input.focus(); results.hidden = true; }
    if (['ArrowDown', 'ArrowUp'].includes(event.key)) {
      event.preventDefault();
      if (results.hidden) showResults();
      const links = [...results.querySelectorAll('a')];
      const index = links.indexOf(document.activeElement);
      if (event.key === 'ArrowDown') links[Math.min(index + 1, links.length - 1)]?.focus();
      else if (index <= 0) input.focus();
      else links[index - 1].focus();
    }
  });
  search.addEventListener('focusout', event => { if (!search.contains(event.relatedTarget)) results.hidden = true; });
  document.addEventListener('click', event => { if (!event.target.closest('.reader-search')) results.hidden = true; });
  document.addEventListener('beforeprint', () => {
    document.querySelectorAll('details').forEach(element => { element.dataset.printOpen = String(element.open); element.open = true; });
  });
  document.addEventListener('afterprint', () => {
    document.querySelectorAll('details[data-print-open]').forEach(element => { element.open = element.dataset.printOpen === 'true'; delete element.dataset.printOpen; });
  });
});
