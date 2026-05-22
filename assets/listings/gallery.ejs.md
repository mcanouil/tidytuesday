```{=html}
<div class="list gallery-grid">
<% for (const item of items) { %>
  <a class="gallery-card" href="<%- item.path %>" <%= metadataAttrs(item) %>>
    <% if (item.image) { %>
      <% const lightSrc = item.image; %>
      <% const darkSrc = item.image.replace(/-light\.svg$/, "-dark.svg"); %>
      <div class="gallery-thumb">
        <img class="light-content" src="<%- lightSrc %>" alt="<%- item.title %>">
        <img class="dark-content" src="<%- darkSrc %>" alt="<%- item.title %>">
      </div>
    <% } %>
    <div class="gallery-meta">
      <% if (item.date) { %>
        <% const d = new Date(item.date); %>
        <time class="gallery-date listing-date"><%= isNaN(d) ? item.date : d.toLocaleDateString("en-GB", { year: "numeric", month: "short", day: "numeric" }) %></time>
      <% } %>
      <h3 class="gallery-title listing-title"><%= item.title %></h3>
      <% if (item.description) { %>
        <p class="gallery-desc listing-description"><%= item.description %></p>
      <% } %>
    </div>
  </a>
<% } %>
</div>
```
