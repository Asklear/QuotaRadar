import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import App from "../../src/App";

describe("App", () => {
  it("renders Quota Radar shell", () => {
    render(<App />);
    expect(screen.getByText("Quota Radar")).toBeInTheDocument();
  });
});
