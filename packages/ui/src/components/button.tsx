import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "cn"
import { Slot } from "radix-ui"

// Tactile depth: a solid "lip" box-shadow under the face, an inset top highlight, and a press that
// sinks the face down onto the lip. Colors derive from the theme tokens so custom themes still work.
const buttonVariants = cva(
  "group/button inline-flex shrink-0 items-center justify-center rounded-lg border border-transparent bg-clip-padding text-sm font-medium whitespace-nowrap transition-all duration-200 ease-[cubic-bezier(0.22,1,0.36,1)] outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 active:not-aria-[haspopup]:translate-y-px active:duration-75 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 motion-reduce:transition-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default:
          "border-[color-mix(in_oklab,var(--primary)_80%,black)] bg-primary text-primary-foreground [text-shadow:0_1px_0_rgba(0,0,0,0.12)] shadow-[inset_0_1px_0_rgba(255,255,255,0.3),0_3px_0_color-mix(in_oklab,var(--primary)_66%,black),0_4px_8px_color-mix(in_oklab,var(--primary)_24%,transparent)] hover:bg-[color-mix(in_oklab,var(--primary)_92%,black)] hover:shadow-[inset_0_1px_0_rgba(255,255,255,0.36),0_3px_0_color-mix(in_oklab,var(--primary)_66%,black),0_6px_12px_color-mix(in_oklab,var(--primary)_30%,transparent)] active:bg-[color-mix(in_oklab,var(--primary)_92%,black)] active:shadow-[inset_0_2px_4px_color-mix(in_oklab,var(--primary)_40%,black),0_2px_0_color-mix(in_oklab,var(--primary)_66%,black),0_3px_6px_color-mix(in_oklab,var(--primary)_22%,transparent)]",
        outline:
          "border-[color-mix(in_oklab,var(--border)_80%,black)] bg-background shadow-[inset_0_1px_0_var(--tactile-highlight),0_2px_0_var(--tactile-lip),0_2px_4px_rgba(15,23,42,0.06)] hover:bg-muted hover:text-foreground hover:shadow-[inset_0_1px_0_var(--tactile-highlight),0_2px_0_var(--tactile-lip),0_3px_6px_rgba(15,23,42,0.08)] active:shadow-[inset_0_2px_3px_rgba(15,23,42,0.06),0_1px_0_var(--tactile-lip)] aria-expanded:bg-muted aria-expanded:text-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50",
        secondary:
          "border-[color-mix(in_oklab,var(--secondary)_82%,black)] bg-secondary text-secondary-foreground shadow-[inset_0_1px_0_var(--tactile-highlight),0_2px_0_color-mix(in_oklab,var(--secondary)_76%,black),0_2px_4px_rgba(15,23,42,0.05)] hover:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)] hover:shadow-[inset_0_1px_0_var(--tactile-highlight),0_2px_0_color-mix(in_oklab,var(--secondary)_76%,black),0_3px_6px_rgba(15,23,42,0.07)] active:shadow-[inset_0_2px_3px_rgba(15,23,42,0.08),0_1px_0_color-mix(in_oklab,var(--secondary)_76%,black)] aria-expanded:bg-secondary aria-expanded:text-secondary-foreground",
        ghost:
          "hover:bg-muted hover:text-foreground aria-expanded:bg-muted aria-expanded:text-foreground dark:hover:bg-muted/50 active:scale-[0.96]",
        destructive:
          "bg-destructive/10 text-destructive shadow-[inset_0_1px_0_rgba(255,255,255,0.5),0_2px_0_color-mix(in_oklab,var(--destructive)_20%,transparent)] hover:bg-destructive/20 hover:shadow-[inset_0_1px_0_rgba(255,255,255,0.5),0_2px_0_color-mix(in_oklab,var(--destructive)_24%,transparent),0_3px_6px_color-mix(in_oklab,var(--destructive)_12%,transparent)] active:shadow-[inset_0_1px_2px_color-mix(in_oklab,var(--destructive)_18%,transparent),0_1px_0_color-mix(in_oklab,var(--destructive)_20%,transparent)] focus-visible:border-destructive/40 focus-visible:ring-destructive/20 dark:bg-destructive/20 dark:hover:bg-destructive/30 dark:focus-visible:ring-destructive/40",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default:
          "h-8 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        xs: "h-6 gap-1 rounded-[min(var(--radius-md),10px)] px-2 text-xs in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3",
        sm: "h-7 gap-1 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3.5",
        lg: "h-9 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        icon: "size-8",
        "icon-xs":
          "size-6 rounded-[min(var(--radius-md),10px)] in-data-[slot=button-group]:rounded-lg [&_svg:not([class*='size-'])]:size-3",
        "icon-sm":
          "size-7 rounded-[min(var(--radius-md),12px)] in-data-[slot=button-group]:rounded-lg",
        "icon-lg": "size-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot.Root : "button"

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }
