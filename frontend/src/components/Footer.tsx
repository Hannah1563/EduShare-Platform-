export default function Footer() {
  return (
    <footer className="footer">
      <div className="container">
        <p>
          © {new Date().getFullYear()} EduShare. Sharing knowledge, empowering African students.
          {" · "}
          <a href="/health">Service status</a>
        </p>
      </div>
    </footer>
  );
}