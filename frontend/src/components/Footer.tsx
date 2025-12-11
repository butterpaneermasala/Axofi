"use client";

export default function Footer() {
  return (
    <footer style={{ padding: 32, textAlign: "center", marginTop: 48 }}>
      <div>© {new Date().getFullYear()} AxoFi</div>
    </footer>
  );
}
