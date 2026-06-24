import { render } from '@testing-library/react';
import { Skeleton, CardSkeleton } from '@/components/Skeleton';

describe('Skeleton Components', () => {
  it('renders Skeleton with default classes', () => {
    const { container } = render(<Skeleton />);
    expect(container.firstChild).toHaveClass('animate-pulse');
    expect(container.firstChild).toHaveClass('bg-gray-200/60');
  });

  it('renders Skeleton with custom classes', () => {
    const { container } = render(<Skeleton className="custom-class" />);
    expect(container.firstChild).toHaveClass('custom-class');
  });

  it('renders CardSkeleton correctly', () => {
    const { container } = render(<CardSkeleton />);
    expect(container.firstChild).toHaveClass('glass');
    
    // There should be multiple skeletons inside the card
    const skeletons = container.querySelectorAll('.animate-pulse');
    expect(skeletons.length).toBeGreaterThan(0);
  });
});
