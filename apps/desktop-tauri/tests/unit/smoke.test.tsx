import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import App from "../../src/App";

describe("App", () => {
  it("renders Quota Radar shell", () => {
    render(<App />);
    expect(screen.getByText("Quota Radar")).toBeInTheDocument();
  });

  it("applies language changes to the shell immediately", () => {
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: "Settings" }));
    fireEvent.change(screen.getByLabelText("Language"), { target: { value: "zh-Hans" } });

    expect(screen.getByRole("button", { name: "设置" })).toBeInTheDocument();
    expect(screen.getByText("API 额度")).toBeInTheDocument();
  });

  it("localizes quota timing and detail status after changing language", () => {
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: "Settings" }));
    fireEvent.change(screen.getByLabelText("Language"), { target: { value: "zh-Hans" } });
    fireEvent.click(screen.getByRole("button", { name: "额度概览" }));

    expect(screen.queryByText(/Jul/)).not.toBeInTheDocument();

    fireEvent.click(screen.getByText("Tavily"));

    expect(screen.getByText("正常")).toBeInTheDocument();
    expect(screen.getByText(/下次重置/)).toBeInTheDocument();
    expect(screen.queryByText("healthy")).not.toBeInTheDocument();
    expect(screen.queryByText(/Reset/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Plan ends/)).not.toBeInTheDocument();
  });
});
