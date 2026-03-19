import { createBrowserRouter } from "react-router";
import Home from "./components/Home";
import Settings from "./components/Settings";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Home,
  },
  {
    path: "/settings",
    Component: Settings,
  },
]);
