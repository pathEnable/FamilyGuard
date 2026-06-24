import { render, screen, fireEvent } from '@testing-library/react';
import ConfirmModal from '@/components/ConfirmModal';

describe('ConfirmModal Component', () => {
  const mockOnConfirm = jest.fn();
  const mockOnCancel = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('does not render when isOpen is false', () => {
    render(
      <ConfirmModal
        isOpen={false}
        title="Delete Item"
        message="Are you sure?"
        onConfirm={mockOnConfirm}
        onCancel={mockOnCancel}
      />
    );
    expect(screen.queryByText('Delete Item')).not.toBeInTheDocument();
  });

  it('renders correctly when isOpen is true', () => {
    render(
      <ConfirmModal
        isOpen={true}
        title="Delete Item"
        message="Are you sure you want to delete this?"
        onConfirm={mockOnConfirm}
        onCancel={mockOnCancel}
      />
    );
    expect(screen.getByText('Delete Item')).toBeInTheDocument();
    expect(screen.getByText('Are you sure you want to delete this?')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Supprimer/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Annuler/i })).toBeInTheDocument();
  });

  it('calls onConfirm when confirm button is clicked', () => {
    render(
      <ConfirmModal
        isOpen={true}
        title="Delete Item"
        message="Are you sure?"
        onConfirm={mockOnConfirm}
        onCancel={mockOnCancel}
      />
    );
    fireEvent.click(screen.getByRole('button', { name: /Supprimer/i }));
    expect(mockOnConfirm).toHaveBeenCalledTimes(1);
  });

  it('calls onCancel when cancel button is clicked', () => {
    render(
      <ConfirmModal
        isOpen={true}
        title="Delete Item"
        message="Are you sure?"
        onConfirm={mockOnConfirm}
        onCancel={mockOnCancel}
      />
    );
    fireEvent.click(screen.getByRole('button', { name: /Annuler/i }));
    expect(mockOnCancel).toHaveBeenCalledTimes(1);
  });

  it('calls onCancel when Escape key is pressed', () => {
    render(
      <ConfirmModal
        isOpen={true}
        title="Delete Item"
        message="Are you sure?"
        onConfirm={mockOnConfirm}
        onCancel={mockOnCancel}
      />
    );
    fireEvent.keyDown(window, { key: 'Escape', code: 'Escape' });
    expect(mockOnCancel).toHaveBeenCalledTimes(1);
  });
});
