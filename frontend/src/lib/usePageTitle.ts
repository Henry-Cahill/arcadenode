import { useEffect } from 'react'

const BASE_TITLE = 'ArcadeNode'

/**
 * Sets the document title for the current page.
 * Resets to the base title on unmount.
 */
export function usePageTitle(title: string) {
  useEffect(() => {
    const prev = document.title
    document.title = title ? `${title} | ${BASE_TITLE}` : BASE_TITLE
    return () => {
      document.title = prev
    }
  }, [title])
}
